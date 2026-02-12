//
//  MockQuizPersistence.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation

@MainActor
class MockQuizPersistence: QuizService {
    private var quizzes: [QuizModel]

    init(quizzes: [QuizModel] = QuizModel.mocks) {
        self.quizzes = quizzes
    }

    func getAllQuizzes() throws -> [QuizModel] {
        quizzes.sorted { $0.createdAt > $1.createdAt }
    }

    func getQuiz(id: String) throws -> QuizModel? {
        quizzes.first { $0.quizId == id }
    }

    func saveQuiz(quiz: QuizModel) throws {
        if let index = quizzes.firstIndex(where: { $0.quizId == quiz.quizId }) {
            quizzes[index] = quiz
        } else {
            quizzes.append(quiz)
        }
    }

    func deleteQuiz(id: String) throws {
        quizzes.removeAll { $0.quizId == id }
    }
}
