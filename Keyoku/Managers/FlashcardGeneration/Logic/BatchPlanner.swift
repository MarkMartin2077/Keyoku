//
//  BatchPlanner.swift
//  Keyoku
//

import Foundation

/// What one generated item costs and how many items a single model call may ask for.
struct GenerationProfile: Equatable, Sendable {
    let outputTokensPerItem: Int
    /// One item per this many free tokens, before the per-call floor and ceiling apply.
    let freeTokensPerItem: Int
    let itemsPerCallFloor: Int
    let itemsPerCallCeiling: Int

    /// One card per ~1K free tokens: a 4K window gets 3 cards per call, 8K gets 7, 32K gets 10.
    static let flashcards = GenerationProfile(
        outputTokensPerItem: 90,
        freeTokensPerItem: 1_000,
        itemsPerCallFloor: 3,
        itemsPerCallCeiling: 10
    )

    /// A quiz question costs about twice a card (five fields). A 4K window gets 2 questions per call,
    /// and Private Cloud Compute's 32K window fits a whole 20-question quiz in one call.
    /// Research estimates, to be tuned on a device.
    static let quiz = GenerationProfile(
        outputTokensPerItem: 180,
        freeTokensPerItem: 1_300,
        itemsPerCallFloor: 2,
        itemsPerCallCeiling: 20
    )
}

/// How much source text and how many items fit in one model call, measured for the active model.
struct GenerationBudget: Equatable, Sendable {
    /// The flashcard profile's output cost per card.
    static var outputTokensPerCard: Int { GenerationProfile.flashcards.outputTokensPerItem }
    /// Chunks are cut using the text's average tokens-per-character, so a dense chunk can run over; keep headroom.
    static let sourceSafetyFactor = 0.9
    static let minimumSourceTokens = 256

    let sourceTokens: Int
    /// Items per call. Named for cards, but holds whatever item the profile describes.
    let cardsPerBatch: Int
    let tokensPerCharacter: Double

    /// `overheadTokens` is everything in a call except the source text and the output:
    /// instructions, prompt template and response schema.
    init(contextSize: Int, overheadTokens: Int, tokensPerCharacter: Double, profile: GenerationProfile) {
        let freeTokens = max(contextSize - overheadTokens, 0)
        let items = min(profile.itemsPerCallCeiling, max(profile.itemsPerCallFloor, freeTokens / profile.freeTokensPerItem))
        let source = Double(freeTokens - items * profile.outputTokensPerItem) * Self.sourceSafetyFactor
        self.cardsPerBatch = items
        self.sourceTokens = max(Int(source), Self.minimumSourceTokens)
        self.tokensPerCharacter = tokensPerCharacter > 0 ? tokensPerCharacter : 0.25
    }

    var sourceCharacters: Int {
        max(1, Int(Double(sourceTokens) / tokensPerCharacter))
    }
}

/// Splits a whole document into batches that each fit the budget, and spreads the requested
/// item count across all of them so long documents are covered end to end.
enum BatchPlanner {

    static func plan(text: String, cardCount: Int, budget: GenerationBudget, firstIndex: Int = 0) -> [GenerationBatch] {
        let characterCount = text.count
        guard cardCount > 0, characterCount > 0 else { return [] }

        let chunksForCards = (cardCount + budget.cardsPerBatch - 1) / budget.cardsPerBatch
        let chunksForSize = (characterCount + budget.sourceCharacters - 1) / budget.sourceCharacters
        let chunkCount = max(chunksForCards, chunksForSize)
        let targetCharacters = (characterCount + chunkCount - 1) / chunkCount

        var chunks = split(text, characterCount: characterCount, targetCharacters: targetCharacters)
        mergeShortTail(&chunks, maxCharacters: budget.sourceCharacters, minChunks: chunksForCards)

        let counts = distribute(cardCount, weights: chunks.map(\.count), cap: budget.cardsPerBatch)
        return zip(chunks, counts)
            .filter { $0.1 > 0 }
            .enumerated()
            .map { offset, pair in
                GenerationBatch(index: firstIndex + offset, text: pair.0, cardCount: pair.1)
            }
    }

    /// Spreads `count` over `weights` proportionally. Each share is the floor or ceiling of its exact quota,
    /// and rounding the cumulative quota spreads leftover cards across the document instead of
    /// piling them onto the first chunks. Shares above `cap` overflow one card at a time to the largest chunks with room.
    static func distribute(_ count: Int, weights: [Int], cap: Int) -> [Int] {
        let total = weights.reduce(0, +)
        guard total > 0, count > 0 else { return weights.map { _ in 0 } }

        var shares: [Int] = []
        var cumulativeWeight = 0
        var assigned = 0
        for weight in weights {
            cumulativeWeight += weight
            let cumulativeShare = Int((Double(count) * Double(cumulativeWeight) / Double(total)).rounded())
            shares.append(cumulativeShare - assigned)
            assigned = cumulativeShare
        }

        var overflow = 0
        for index in shares.indices where shares[index] > cap {
            overflow += shares[index] - cap
            shares[index] = cap
        }
        let byWeight = weights.indices.sorted { weights[$0] != weights[$1] ? weights[$0] > weights[$1] : $0 < $1 }
        while overflow > 0, shares.contains(where: { $0 < cap }) {
            for index in byWeight where overflow > 0 && shares[index] < cap {
                shares[index] += 1
                overflow -= 1
            }
        }
        return shares
    }

    /// Halves a batch that overflowed the context window. Both halves keep the batch's index.
    static func splitInHalf(_ batch: GenerationBatch) -> [GenerationBatch] {
        let text = batch.text
        guard text.count > 1 else { return [batch] }
        let middle = text.index(text.startIndex, offsetBy: text.count / 2)
        let cut = findBreak(in: text, before: middle, from: text.startIndex)
        let firstCount = batch.cardCount - batch.cardCount / 2
        return [
            GenerationBatch(index: batch.index, text: String(text[..<cut]), cardCount: firstCount),
            GenerationBatch(index: batch.index, text: String(text[cut...]), cardCount: batch.cardCount / 2)
        ].filter { $0.cardCount > 0 }
    }

    // MARK: - Splitting

    private static func split(_ text: String, characterCount: Int, targetCharacters: Int) -> [String] {
        var chunks: [String] = []
        var start = text.startIndex
        var remaining = characterCount

        while remaining > targetCharacters {
            let target = text.index(start, offsetBy: targetCharacters)
            let cut = findBreak(in: text, before: target, from: start)
            let chunk = text[start..<cut]
            chunks.append(String(chunk))
            remaining -= chunk.count
            start = cut
        }
        if start < text.endIndex {
            chunks.append(String(text[start...]))
        }
        return chunks
    }

    /// Backward-only cut points keep every chunk at or under the target, but can leave a sliver at the end.
    private static func mergeShortTail(_ chunks: inout [String], maxCharacters: Int, minChunks: Int) {
        guard chunks.count > max(minChunks, 1),
              let tail = chunks.last,
              chunks[chunks.count - 2].count + tail.count <= maxCharacters
        else { return }
        chunks.removeLast()
        chunks[chunks.count - 1] += tail
    }

    /// Finds the best cut point in the last third before `target`: paragraph, line, sentence, then word.
    /// The cut is always after `start` and never after `target`.
    static func findBreak(in text: String, before target: String.Index, from start: String.Index) -> String.Index {
        let radius = max(text.distance(from: start, to: target) / 3, 1)
        let windowStart = text.index(target, offsetBy: -radius, limitedBy: start) ?? start
        let window = text[windowStart..<target]

        for separator in ["\n\n", "\n", ". ", "? ", "! "] {
            if let range = window.range(of: separator, options: .backwards) {
                return range.upperBound
            }
        }
        if let space = window.lastIndex(where: \.isWhitespace) {
            return text.index(after: space)
        }
        return target
    }
}
