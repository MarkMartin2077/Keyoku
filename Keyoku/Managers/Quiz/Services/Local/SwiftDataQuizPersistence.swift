//
//  SwiftDataQuizPersistence.swift
//  Keyoku
//

import Foundation
import SwiftData

/// Stores quizzes in their own SwiftData container ("QuizStore"), separate
/// from "DeckStore" so the deck schema is never touched (ADR 0003).
@MainActor
struct SwiftDataQuizPersistence: QuizService {
    private let container: ModelContainer

    private var mainContext: ModelContext {
        container.mainContext
    }

    init() {
        let config = ModelConfiguration("QuizStore")
        // swiftlint:disable:next force_try
        self.container = try! ModelContainer(for: QuizEntity.self, configurations: config)
    }

    func getAllQuizzes() throws -> [QuizModel] {
        let descriptor = FetchDescriptor<QuizEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try mainContext.fetch(descriptor).map { try $0.toModel() }
    }

    func saveQuiz(_ quiz: QuizModel) throws {
        let quizId = quiz.id
        var descriptor = FetchDescriptor<QuizEntity>(predicate: #Predicate { $0.id == quizId })
        descriptor.fetchLimit = 1

        if let existing = try mainContext.fetch(descriptor).first {
            try existing.update(from: quiz)
        } else {
            mainContext.insert(try QuizEntity(from: quiz))
        }

        try mainContext.save()
    }

    func deleteQuiz(id: String) throws {
        try mainContext.delete(model: QuizEntity.self, where: #Predicate { $0.id == id })
        try mainContext.save()
    }

    func deleteQuizzes(deckId: String) throws {
        try mainContext.delete(model: QuizEntity.self, where: #Predicate { $0.deckId == deckId })
        try mainContext.save()
    }
}
