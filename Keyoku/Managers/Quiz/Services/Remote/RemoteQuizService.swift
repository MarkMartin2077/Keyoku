//
//  RemoteQuizService.swift
//  Keyoku
//

import Foundation

/// Remote storage for quizzes, flat under `users/{uid}/quizzes/{quizId}`.
@MainActor
protocol RemoteQuizService: Sendable {
    func getAllQuizzes(userId: String) async throws -> [QuizModel]
    func saveQuiz(userId: String, quiz: QuizModel) async throws
    func deleteQuiz(userId: String, quizId: String) async throws
    func deleteQuizzes(userId: String, deckId: String) async throws
    func deleteAllQuizzes(userId: String) async throws
}
