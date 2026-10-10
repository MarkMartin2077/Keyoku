//
//  QuizEntity.swift
//  Keyoku
//

import Foundation
import SwiftData

/// SwiftData row for a quiz in the "QuizStore" container.
///
/// `deckId` is a plain string with no relationship to `DeckEntity` (ADR 0003).
/// Questions and attempts are stored as JSON-encoded `Data`, so a quiz is
/// always read and written as one unit.
@Model
final class QuizEntity {
    #Index<QuizEntity>([\.deckId])

    @Attribute(.unique) var id: String = UUID().uuidString
    var deckId: String = ""
    var title: String = ""
    var createdAt: Date = Date.now
    var questionsData = Data()
    var attemptsData = Data()

    init(id: String, deckId: String, title: String, createdAt: Date, questionsData: Data, attemptsData: Data) {
        self.id = id
        self.deckId = deckId
        self.title = title
        self.createdAt = createdAt
        self.questionsData = questionsData
        self.attemptsData = attemptsData
    }

    convenience init(from model: QuizModel) throws {
        self.init(
            id: model.id,
            deckId: model.deckId,
            title: model.title,
            createdAt: model.createdAt,
            questionsData: try JSONEncoder().encode(model.questions),
            attemptsData: try JSONEncoder().encode(model.attempts)
        )
    }

    /// Overwrites every stored field with the values from `model`.
    func update(from model: QuizModel) throws {
        deckId = model.deckId
        title = model.title
        createdAt = model.createdAt
        questionsData = try JSONEncoder().encode(model.questions)
        attemptsData = try JSONEncoder().encode(model.attempts)
    }

    func toModel() throws -> QuizModel {
        QuizModel(
            id: id,
            deckId: deckId,
            title: title,
            createdAt: createdAt,
            questions: try JSONDecoder().decode([QuizQuestionModel].self, from: questionsData),
            attempts: try JSONDecoder().decode([QuizAttemptModel].self, from: attemptsData)
        )
    }
}
