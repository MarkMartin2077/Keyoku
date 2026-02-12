//
//  RemoteQuizService.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation

@MainActor
protocol RemoteQuizService: Sendable {
    func getAllQuizzes(userId: String) async throws -> [QuizModel]
    func getQuiz(userId: String, quizId: String) async throws -> QuizModel
    func saveQuiz(userId: String, quiz: QuizModel) async throws
    func deleteQuiz(userId: String, quizId: String) async throws
}
