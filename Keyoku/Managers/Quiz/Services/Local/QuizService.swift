//
//  QuizService.swift
//  Keyoku
//

import Foundation

/// The result of reading every stored quiz.
struct QuizLoadResult {
    /// Every quiz that decoded, newest first.
    let quizzes: [QuizModel]
    /// How many stored rows couldn't be decoded and were left out.
    let skippedCount: Int
}

/// Local, synchronous storage for quizzes.
@MainActor
protocol QuizService {
    func getAllQuizzes() throws -> QuizLoadResult
    func saveQuiz(_ quiz: QuizModel) throws
    func deleteQuiz(id: String) throws
    func deleteQuizzes(deckId: String) throws
}
