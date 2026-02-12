//
//  QuizEntity.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation
import SwiftData

@Model
class QuizEntity {
    @Attribute(.unique) var id: String = UUID().uuidString
    var name: String = ""
    var colorRaw: String = DeckColor.blue.rawValue
    var sourceText: String = ""
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \QuizQuestionEntity.quiz)
    var questions: [QuizQuestionEntity] = []

    var color: DeckColor {
        get { DeckColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }

    init(id: String = UUID().uuidString, name: String, color: DeckColor = .blue, sourceText: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorRaw = color.rawValue
        self.sourceText = sourceText
        self.createdAt = createdAt
    }

    convenience init(from model: QuizModel) {
        self.init(id: model.quizId, name: model.name, color: model.color, sourceText: model.sourceText, createdAt: model.createdAt)
        self.questions = model.questions.map { question in
            let entity = QuizQuestionEntity(from: question)
            entity.quiz = self
            return entity
        }
    }

    func toModel() -> QuizModel {
        QuizModel(
            quizId: id,
            name: name,
            color: color,
            sourceText: sourceText,
            createdAt: createdAt,
            questions: questions.map { $0.toModel() }
        )
    }
}
