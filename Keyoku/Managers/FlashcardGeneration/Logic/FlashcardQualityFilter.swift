//
//  FlashcardQualityFilter.swift
//  Keyoku
//

import Foundation

/// Rejects incomplete cards and cards that talk about "the text" instead of the concept,
/// and deduplicates questions across batches and against questions the deck already has.
struct FlashcardQualityFilter {
    static let minQuestionLength = 5
    static let minAnswerLength = 10

    private static let leakPhrases: [[Substring]] = ["source text", "in the text", "the text"]
        .map { $0.split(separator: " ") }

    private var seenQuestions: Set<String>

    init(avoiding existingQuestions: [String] = []) {
        seenQuestions = Set(existingQuestions.map(Self.normalized))
    }

    /// Returns the cards worth keeping, in order, and remembers their questions for later batches.
    mutating func accept(_ cards: [FlashcardModel]) -> [FlashcardModel] {
        cards.filter { card in
            guard Self.isComplete(question: card.question, answer: card.answer),
                  !Self.referencesSource(card.question),
                  !Self.referencesSource(card.answer)
            else { return false }
            return seenQuestions.insert(Self.normalized(card.question)).inserted
        }
    }

    static func isComplete(question: String, answer: String) -> Bool {
        question.trimmingCharacters(in: .whitespacesAndNewlines).count >= minQuestionLength &&
        answer.trimmingCharacters(in: .whitespacesAndNewlines).count >= minAnswerLength
    }

    /// Whole-phrase match, so "the text" rejects "according to the text" but not "the textbook".
    static func referencesSource(_ string: String) -> Bool {
        let words = string.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        return leakPhrases.contains { phrase in
            guard words.count >= phrase.count else { return false }
            return (0...(words.count - phrase.count)).contains { start in
                words[start..<(start + phrase.count)].elementsEqual(phrase)
            }
        }
    }

    static func normalized(_ question: String) -> String {
        question.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
