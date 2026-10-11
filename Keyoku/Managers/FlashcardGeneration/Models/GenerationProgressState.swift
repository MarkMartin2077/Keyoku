//
//  GenerationProgressState.swift
//  Keyoku
//

import Foundation

/// What a generating screen shows, folded from `GenerationEvent`s.
struct GenerationProgressState {
    private(set) var model: GenerationModelKind?
    private(set) var plannedBatchCount = 0
    private(set) var committedCards: [Int: [FlashcardModel]] = [:]
    private(set) var partial: (batch: Int, cards: [FlashcardModel])?
    private(set) var skippedCounts: [SkipReason: Int] = [:]
    private var highestBatchIndex = -1

    mutating func apply(_ event: GenerationEvent) {
        switch event {
        case .started(let model, let batchCount):
            self.model = model
            plannedBatchCount = batchCount
        case .modelChanged(let model):
            self.model = model
            partial = nil
        case .partial(let batch, let cards):
            noteBatch(batch)
            partial = (batch, cards)
        case .batchCompleted(let batch, let cards):
            noteBatch(batch)
            committedCards[batch] = cards
            clearPartial(of: batch)
        case .batchSkipped(let batch, let reason):
            noteBatch(batch)
            skippedCounts[reason, default: 0] += 1
            clearPartial(of: batch)
        }
    }

    /// Final cards in batch order.
    var cards: [FlashcardModel] {
        committedCards.keys.sorted().flatMap { committedCards[$0] ?? [] }
    }

    /// Final cards followed by the in-flight batch's streaming preview.
    var previewCards: [FlashcardModel] {
        cards + (partial?.cards ?? [])
    }

    var finishedBatchCount: Int {
        committedCards.count + skippedCount
    }

    /// A fallback or a top-up batch can add batches beyond the initial plan.
    var totalBatchCount: Int {
        max(plannedBatchCount, highestBatchIndex + 1)
    }

    var currentBatchNumber: Int {
        min(finishedBatchCount + 1, max(totalBatchCount, 1))
    }

    var skippedCount: Int {
        skippedCounts.values.reduce(0, +)
    }

    var skippedSummary: String? {
        guard skippedCount > 0 else { return nil }
        // Guardrail blocks and refusals both read as content restrictions to the learner.
        let reasons = [
            ([SkipReason.unreadableText], String(localized: "unreadable text")),
            ([.restricted, .refused], String(localized: "content restrictions")),
            ([.failed], String(localized: "generation errors"))
        ]
            .filter { reasons, _ in reasons.contains { skippedCounts[$0, default: 0] > 0 } }
            .map(\.1)
            .formatted(.list(type: .and))
        return String(localized: "\(skippedCount) section(s) skipped: \(reasons)")
    }

    private mutating func noteBatch(_ batch: Int) {
        highestBatchIndex = max(highestBatchIndex, batch)
    }

    private mutating func clearPartial(of batch: Int) {
        if partial?.batch == batch {
            partial = nil
        }
    }
}
