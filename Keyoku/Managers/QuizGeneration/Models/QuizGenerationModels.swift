//
//  QuizGenerationModels.swift
//  Keyoku
//

import Foundation

/// A generated quiz, ready to save. Its questions passed the quality filter.
struct GeneratedQuiz: Equatable, Sendable {
    let title: String
    let questions: [QuizQuestionModel]
    /// Whether the title is the "<Deck name> Quiz" fallback rather than a generated one.
    let usedFallbackTitle: Bool
}

/// Generation progress as counts only, so nothing about the questions is revealed before the quiz is played.
struct QuizGenerationProgress: Equatable, Sendable {
    let generatedCount: Int
    let totalCount: Int
}

enum QuizGenerationError: Error, Equatable {
    /// The source text is shorter than `QuizQuestionCount.minimumSourceLength`.
    case notEnoughSourceText
    /// Fewer than `QuizQuestionCount.minimum` questions survived the filter and the top-up.
    case tooFewQuestions(generated: Int)
    case generation(GenerationFailure)

    var isCancelled: Bool {
        self == .generation(.cancelled)
    }

    var userMessage: String {
        switch self {
        case .notEnoughSourceText:
            return String(localized: "Add more source text to make a quiz.")
        case .tooFewQuestions:
            return String(localized: "Couldn't write enough good questions from this deck. Try again, or add more source text.")
        case .generation(let failure):
            return failure.userMessage
        }
    }

    var analyticsName: String {
        switch self {
        case .notEnoughSourceText: return "not_enough_source_text"
        case .tooFewQuestions: return "too_few_questions"
        case .generation(let failure): return failure.analyticsName
        }
    }
}
