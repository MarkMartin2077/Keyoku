//
//  MockRemoteQuizService.swift
//  Keyoku
//

import Foundation

/// In-memory remote store. Keeps the quizzes it holds so tests can observe
/// what the manager pushed and deleted.
@MainActor
final class MockRemoteQuizService: RemoteQuizService {

    private(set) var quizzes: [QuizModel]
    private let deleteDelay: Duration

    /// - Parameter deleteDelay: How long each single-quiz delete takes, like a slow or offline Firestore.
    init(quizzes: [QuizModel] = [], deleteDelay: Duration = .zero) {
        self.quizzes = quizzes
        self.deleteDelay = deleteDelay
    }

    func getAllQuizzes(userId: String) async throws -> [QuizModel] {
        quizzes
    }

    func saveQuiz(userId: String, quiz: QuizModel) async throws {
        if let index = quizzes.firstIndex(where: { $0.id == quiz.id }) {
            quizzes[index] = quiz
        } else {
            quizzes.append(quiz)
        }
    }

    func deleteQuiz(userId: String, quizId: String) async throws {
        try await Task.sleep(for: deleteDelay)
        quizzes.removeAll { $0.id == quizId }
    }

    func deleteQuizzes(userId: String, deckId: String) async throws {
        quizzes.removeAll { $0.deckId == deckId }
    }

    func deleteAllQuizzes(userId: String) async throws {
        quizzes.removeAll()
    }
}
