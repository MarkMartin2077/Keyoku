//
//  MockRemoteQuizService.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation

struct MockRemoteQuizService: RemoteQuizService {

    private var quizzes: [QuizModel]

    init(quizzes: [QuizModel] = []) {
        self.quizzes = quizzes
    }

    func getAllQuizzes(userId: String) async throws -> [QuizModel] {
        quizzes
    }

    func getQuiz(userId: String, quizId: String) async throws -> QuizModel {
        guard let quiz = quizzes.first(where: { $0.quizId == quizId }) else {
            throw NSError(domain: "MockRemoteQuizService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Quiz not found"])
        }
        return quiz
    }

    func saveQuiz(userId: String, quiz: QuizModel) async throws {
        // No-op for mock
    }

    func deleteQuiz(userId: String, quizId: String) async throws {
        // No-op for mock
    }
}
