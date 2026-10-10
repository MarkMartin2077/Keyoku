//
//  QuizQualityFilter.swift
//  Keyoku
//

import Foundation

/// Keeps only well-formed quiz questions: every field filled, exactly three distinct wrong answers,
/// none of them equal to the correct answer, and nothing that talks about "the text".
/// Deduplicates questions across batches and against the deck's other quizzes.
struct QuizQualityFilter {
    static let wrongAnswerCount = 3

    private var seenQuestions: Set<String>

    init(avoiding existingQuestions: [String] = []) {
        seenQuestions = Set(existingQuestions.map(FlashcardQualityFilter.normalized))
    }

    /// Returns the questions worth keeping, in order, and remembers them for later batches.
    mutating func accept(_ questions: [QuizQuestionModel]) -> [QuizQuestionModel] {
        questions.filter { question in
            guard Self.isWellFormed(question) else { return false }
            return seenQuestions.insert(FlashcardQualityFilter.normalized(question.question)).inserted
        }
    }

    /// Every field is filled and there are exactly three wrong answers.
    static func isComplete(_ question: QuizQuestionModel) -> Bool {
        question.wrongAnswers.count == wrongAnswerCount && allFields(of: question).allSatisfy { !isBlank($0) }
    }

    /// Complete, with four distinct answers and no reference to the source.
    static func isWellFormed(_ question: QuizQuestionModel) -> Bool {
        guard isComplete(question) else { return false }
        let answers = ([question.correctAnswer] + question.wrongAnswers).map(FlashcardQualityFilter.normalized)
        guard Set(answers).count == answers.count else { return false }
        return !allFields(of: question).contains(where: FlashcardQualityFilter.referencesSource)
    }

    private static func allFields(of question: QuizQuestionModel) -> [String] {
        [question.question, question.correctAnswer, question.explanation] + question.wrongAnswers
    }

    private static func isBlank(_ string: String) -> Bool {
        string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
