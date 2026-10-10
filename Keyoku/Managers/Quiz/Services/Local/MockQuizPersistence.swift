//
//  MockQuizPersistence.swift
//  Keyoku
//

import Foundation

@MainActor
class MockQuizPersistence: QuizService {
    private var quizzes: [QuizModel]
    private let skippedCount: Int

    /// - Parameter skippedCount: How many corrupt rows every read reports skipping.
    init(quizzes: [QuizModel] = QuizModel.mocks, skippedCount: Int = 0) {
        self.quizzes = quizzes
        self.skippedCount = skippedCount
    }

    func getAllQuizzes() throws -> QuizLoadResult {
        QuizLoadResult(quizzes: quizzes.sorted { $0.createdAt > $1.createdAt }, skippedCount: skippedCount)
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
