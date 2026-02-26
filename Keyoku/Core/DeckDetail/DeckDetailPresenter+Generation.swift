//
//  DeckDetailPresenter+Generation.swift
//  Keyoku
//
//  Created by Mark Martin on 2/17/26.
//

import SwiftUI
import FoundationModels

// MARK: - Text Splitting

extension DeckDetailPresenter {

    func findBreak(in text: String, near target: String.Index, from start: String.Index) -> String.Index {
        let searchRadius = max(text.distance(from: start, to: target) / 3, 1)
        let searchStart = text.index(target, offsetBy: -searchRadius, limitedBy: start) ?? start
        let searchEnd = text.index(target, offsetBy: searchRadius, limitedBy: text.endIndex) ?? text.endIndex
        let window = text[searchStart..<searchEnd]

        if let range = window.range(of: "\n\n", options: .backwards) {
            return range.upperBound
        }

        if let range = window.range(of: "\n", options: .backwards) {
            return range.upperBound
        }

        for ender in [". ", "? ", "! "] {
            if let range = window.range(of: ender, options: .backwards) {
                return range.upperBound
            }
        }

        return text[target...].firstIndex(where: \.isWhitespace) ?? target
    }

    func splitText(_ text: String, into count: Int) -> [String] {
        guard count > 1 else { return [text] }

        let chunkSize = text.count / count
        var chunks = [String]()
        var startIndex = text.startIndex

        for index in 0..<count {
            if index == count - 1 {
                chunks.append(String(text[startIndex...]))
            } else {
                let targetEnd = text.index(startIndex, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
                let breakIndex = findBreak(in: text, near: targetEnd, from: startIndex)
                chunks.append(String(text[startIndex..<breakIndex]))
                startIndex = breakIndex
            }
        }

        return chunks
    }

    func makeChunks(maxTextPerBatch: Int, itemCount: Int, maxItemsPerBatch: Int) -> [String] {
        let minBatches = Int(ceil(Double(itemCount) / Double(maxItemsPerBatch)))
        let textChunks = splitTextByMaxSize(sourceText, maxChars: maxTextPerBatch)
        return textChunks.count < minBatches
            ? splitText(sourceText, into: minBatches)
            : textChunks
    }

    func splitTextByMaxSize(_ text: String, maxChars: Int) -> [String] {
        guard text.count > maxChars else { return [text] }

        var chunks = [String]()
        var startIndex = text.startIndex

        while startIndex < text.endIndex {
            let remaining = text.distance(from: startIndex, to: text.endIndex)

            if remaining <= maxChars {
                chunks.append(String(text[startIndex...]))
                break
            }

            let targetEnd = text.index(startIndex, offsetBy: maxChars, limitedBy: text.endIndex) ?? text.endIndex
            let breakIndex = findBreak(in: text, near: targetEnd, from: startIndex)
            chunks.append(String(text[startIndex..<breakIndex]))
            startIndex = breakIndex
        }

        return chunks
    }
}

// MARK: - Session Configuration

extension DeckDetailPresenter {

    func makeSession() -> LanguageModelSession {
        let instructions = """
            You are an educational study aid assistant for a flashcard app. \
            Your ONLY task is to create flashcards \
            EXCLUSIVELY from the source text provided by the user. \
            EVERY question, answer, and flashcard you generate MUST be directly \
            based on information found in the provided source text. \
            NEVER use outside knowledge, general trivia, or unrelated facts. \
            If a concept is not mentioned in the source text, do NOT create \
            a question about it. \
            You MUST process the source material professionally and objectively, \
            even if it covers sensitive historical events, medical topics, scientific concepts, \
            legal cases, or other academic subjects. \
            Source text may also come from fiction or fantasy books. Treat this content \
            neutrally — users study these to track characters, events, plot points, \
            and world-building details as learning material. \
            ALWAYS focus on creating accurate, educational content. \
            NEVER refuse to create study materials from legitimate text.
            """
        return LanguageModelSession(instructions: instructions)
    }

    private func looksLikeGibberish(_ text: String) -> Bool {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })

        if words.count < 5 && text.count > 200 {
            return true
        }

        let lowercasedWords = words.map { $0.lowercased() }
        let uniqueWords = Set(lowercasedWords)
        let uniqueRatio = Double(uniqueWords.count) / Double(max(1, words.count))
        if words.count >= 5 && uniqueRatio < 0.25 {
            return true
        }

        if text.count > 200 {
            let anchors: Set<String> = [
                "the", "a", "an", "in", "is", "it", "of", "to", "and", "or",
                "on", "be", "are", "was", "for", "this", "that", "with", "not",
                "have", "as", "at", "by", "from", "we", "he", "she", "you", "they"
            ]
            if uniqueWords.isDisjoint(with: anchors) {
                return true
            }
        }

        return false
    }

    func validateChunk(_ text: String) -> Bool {
        !looksLikeGibberish(text)
    }
}

// MARK: - Flashcard Generation

extension DeckDetailPresenter {

    func generateFlashcards() async throws {
        let maxCardsPerBatch = 3
        let chunks = makeChunks(maxTextPerBatch: 5000, itemCount: cardCount, maxItemsPerBatch: maxCardsPerBatch)

        flashcardTotal = chunks.count
        flashcardProgress = 0
        flashcardSkippedBatches = 0

        for chunk in chunks {
            flashcardProgress += 1

            let cardsStillNeeded = cardCount - streamedFlashcards.count
            guard cardsStillNeeded > 0 else { break }
            let batchCards = min(cardsStillNeeded, maxCardsPerBatch)

            flashcardStatusText = "Validating..."
            guard validateChunk(chunk) else {
                flashcardSkippedBatches += 1
                flashcardStatusText = "Skipped"
                continue
            }

            flashcardStatusText = "Generating..."
            interactor.trackEvent(event: Event.onGenerateCardsBatchStart(batchNumber: flashcardProgress, totalBatches: flashcardTotal, cardCount: batchCards))

            do {
                try await streamFlashcardBatch(text: chunk, count: batchCards)
            } catch {
                flashcardSkippedBatches += 1
                flashcardStatusText = "Skipped"
                continue
            }
        }
    }

    private static let minAnswerLength = 10

    private func streamFlashcardBatch(text: String, count: Int) async throws {
        let session = makeSession()
        let prompt = """
        Generate exactly \(count) flashcards ONLY from the source text below. \
        Every question and answer MUST come directly from information in this text. \
        Do NOT include any questions about topics, events, or facts not explicitly \
        covered in the source text. \
        Create cards that help students learn effectively using these techniques:
        - Key definitions and terminology from the text
        - Cause and effect relationships described in the text
        - Compare and contrast concepts mentioned in the text
        - Important dates, timelines, or sequences from the text
        - Formulas, rules, or principles stated in the text
        - Key facts and their significance as presented in the text

        CRITICAL RULES:
        - Every answer MUST be a complete, substantive response (at least 1-2 sentences). \
        - NEVER leave an answer incomplete, truncated, or cut off mid-sentence. \
        - If you cannot provide a full answer for a card, omit that card entirely. \
        - Finish writing each card's answer completely before starting the next card. \
        - Quality over quantity: it is better to produce fewer complete cards \
        than many incomplete ones.

        Source text:
        \(text)
        """

        let stream = session.streamResponse(to: prompt, generating: GeneratedFlashcardBatch.self)
        let countBeforeBatch = streamedFlashcards.count
        var batchIds: [String] = []

        for try await snapshot in stream {
            let completedCards = snapshot.content.cards?.compactMap { partialCard -> FlashcardModel? in
                guard let question = partialCard.question,
                      let answer = partialCard.answer,
                      question.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5,
                      answer.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minAnswerLength
                else { return nil }
                return FlashcardModel(question: question, answer: answer)
            } ?? []

            let cappedCards = Array(completedCards.prefix(count))

            while batchIds.count < cappedCards.count {
                batchIds.append(UUID().uuidString)
            }
            let stableCards = cappedCards.enumerated().map { index, card in
                FlashcardModel(flashcardId: batchIds[index], question: card.question, answer: card.answer)
            }

            streamedFlashcards = Array(streamedFlashcards.prefix(countBeforeBatch)) + stableCards
            flashcardItemsGenerated = streamedFlashcards.count
        }

        applyQualityFilter(from: countBeforeBatch)
    }

    private func applyQualityFilter(from startIndex: Int) {
        let qualityCards = streamedFlashcards.suffix(from: startIndex).filter { card in
            let answer = card.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            let endsCleanly = answer.last == "." || answer.last == "!" || answer.last == "?" || answer.last == ")" || answer.last == "\""
            guard answer.count >= Self.minAnswerLength && endsCleanly else { return false }

            let lowercasedQuestion = card.question.lowercased()
            let leakPhrases = ["source text", "in the text", "the text"]
            if leakPhrases.contains(where: { lowercasedQuestion.contains($0) }) { return false }

            return true
        }
        streamedFlashcards = Array(streamedFlashcards.prefix(startIndex)) + Array(qualityCards)
        flashcardItemsGenerated = streamedFlashcards.count
    }
}
