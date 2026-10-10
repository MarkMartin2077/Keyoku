//
//  QuizService.swift
//  Keyoku
//

import Foundation

/// Local, synchronous storage for quizzes.
@MainActor
protocol QuizService {
    func getAllQuizzes() throws -> [QuizModel]
    func saveQuiz(_ quiz: QuizModel) throws
    func deleteQuiz(id: String) throws
    func deleteQuizzes(deckId: String) throws
}
