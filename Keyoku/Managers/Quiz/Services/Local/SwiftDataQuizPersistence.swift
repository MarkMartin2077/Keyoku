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

    /// Uses the given container, for example an in-memory one in tests.
    init(container: ModelContainer) {
        self.container = container
    }

    func getAllQuizzes() throws -> QuizLoadResult {
        let descriptor = FetchDescriptor<QuizEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let entities = try mainContext.fetch(descriptor)
        // One corrupt row must not hide every other quiz, so rows that fail to decode are skipped.
        let quizzes = entities.compactMap { try? $0.toModel() }
        return QuizLoadResult(quizzes: quizzes, skippedCount: entities.count - quizzes.count)
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
