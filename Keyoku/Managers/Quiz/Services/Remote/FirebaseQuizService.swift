//
//  FirebaseQuizService.swift
//  Keyoku
//

import FirebaseFirestore
import SwiftfulFirestore

struct FirebaseQuizService: RemoteQuizService {

    private func collection(userId: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(userId).collection("quizzes")
    }

    func getAllQuizzes(userId: String) async throws -> [QuizModel] {
        try await collection(userId: userId).getAllDocuments()
    }

    func saveQuiz(userId: String, quiz: QuizModel) async throws {
        try collection(userId: userId).document(quiz.id).setData(from: quiz, merge: false)
    }

    func deleteQuiz(userId: String, quizId: String) async throws {
        try await collection(userId: userId).document(quizId).delete()
    }

    /// Deletes every quiz for a deck with one `deck_id` query and one batched write.
    func deleteQuizzes(userId: String, deckId: String) async throws {
        let snapshot = try await collection(userId: userId)
            .whereField(QuizModel.CodingKeys.deckId.rawValue, isEqualTo: deckId)
            .getDocuments()
        guard !snapshot.documents.isEmpty else { return }

        let batch = Firestore.firestore().batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
    }

    func deleteAllQuizzes(userId: String) async throws {
        try await collection(userId: userId).deleteAllDocuments()
    }
}
