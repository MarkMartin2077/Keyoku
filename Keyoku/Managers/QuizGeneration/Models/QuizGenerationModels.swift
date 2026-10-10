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
            return Self.userMessage(for: failure)
        }
    }

    /// Quiz wording for a generation failure; `GenerationFailure.userMessage` talks about flashcards.
    private static func userMessage(for failure: GenerationFailure) -> String {
        switch failure {
        case .contextTooLarge:
            return String(localized: "This deck's text is too long to make a quiz in one go. Try a deck with a shorter excerpt.")
        case .restricted:
            return String(localized: "Apple Intelligence couldn't make a quiz from this content because of its safety guidelines. Try different study material.")
        case .rateLimited:
            return String(localized: "Apple Intelligence is busy right now. Wait a moment and try again.")
        case .unsupportedLanguage:
            return String(localized: "This deck's language isn't supported by Apple Intelligence yet.")
        case .modelUnavailable:
            return String(localized: "Apple Intelligence isn't available right now. Check that it's turned on in Settings, then try again.")
        case .cloudUnavailable:
            return String(localized: "Couldn't reach Private Cloud Compute. Check your connection and try again.")
        case .cancelled:
            return String(localized: "Quiz generation was cancelled.")
        case .unreadableText:
            return String(localized: "Couldn't write quiz questions from this deck's text. Try a deck made from notes, a textbook excerpt, or an article.")
        case .other:
            return String(localized: "Something went wrong while making the quiz. Please try again.")
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
