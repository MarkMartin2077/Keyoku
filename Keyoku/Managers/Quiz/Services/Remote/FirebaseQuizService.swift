//
//  FirebaseQuizService.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
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

    func getQuiz(userId: String, quizId: String) async throws -> QuizModel {
        try await collection(userId: userId).getDocument(id: quizId)
    }

    func saveQuiz(userId: String, quiz: QuizModel) async throws {
        try collection(userId: userId).document(quiz.quizId).setData(from: quiz, merge: true)
    }

    func deleteQuiz(userId: String, quizId: String) async throws {
        try await collection(userId: userId).document(quizId).delete()
    }
}
