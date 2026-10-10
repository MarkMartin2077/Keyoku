//
//  MockQuizPersistence.swift
//  Keyoku
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

    func saveQuiz(_ quiz: QuizModel) throws {
        if let index = quizzes.firstIndex(where: { $0.id == quiz.id }) {
            quizzes[index] = quiz
        } else {
            quizzes.append(quiz)
        }
    }

    func deleteQuiz(id: String) throws {
        quizzes.removeAll { $0.id == id }
    }

    func deleteQuizzes(deckId: String) throws {
        quizzes.removeAll { $0.deckId == deckId }
    }
}
