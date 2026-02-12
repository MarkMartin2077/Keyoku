//
//  QuizModel.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation
import IdentifiableByString

struct QuizModel: StringIdentifiable, Codable, Sendable {
    var id: String {
        quizId
    }

    let quizId: String
    let name: String
    let color: DeckColor
    let sourceText: String
    let createdAt: Date
    let questions: [QuizQuestionModel]

    init(
        quizId: String = UUID().uuidString,
        name: String,
        color: DeckColor = .blue,
        sourceText: String,
        createdAt: Date = .now,
        questions: [QuizQuestionModel] = []
    ) {
        self.quizId = quizId
        self.name = name
        self.color = color
        self.sourceText = sourceText
        self.createdAt = createdAt
        self.questions = questions
    }

    init(entity: QuizEntity) {
        self.quizId = entity.id
        self.name = entity.name
        self.color = entity.color
        self.sourceText = entity.sourceText
        self.createdAt = entity.createdAt
        self.questions = entity.questions.map { QuizQuestionModel(entity: $0) }
    }

    enum CodingKeys: String, CodingKey {
        case quizId = "quiz_id"
        case name
        case color
        case sourceText = "source_text"
        case createdAt = "created_at"
        case questions
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "quiz_\(CodingKeys.quizId.rawValue)": quizId,
            "quiz_\(CodingKeys.name.rawValue)": name,
            "quiz_\(CodingKeys.color.rawValue)": color.rawValue,
            "quiz_\(CodingKeys.sourceText.rawValue)": sourceText,
            "quiz_\(CodingKeys.createdAt.rawValue)": createdAt,
            "quiz_question_count": questions.count
        ]
        return dict.compactMapValues({ $0 })
    }

    func toEntity() -> QuizEntity {
        let entity = QuizEntity(
            id: quizId,
            name: name,
            color: color,
            sourceText: sourceText,
            createdAt: createdAt
        )
        entity.questions = questions.map { question in
            let questionEntity = question.toEntity()
            questionEntity.quiz = entity
            return questionEntity
        }
        return entity
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        let now = Date()
        return [
            QuizModel(
                quizId: "quiz1",
                name: "World Geography",
                color: .red,
                sourceText: "Geography facts and capitals",
                createdAt: now,
                questions: Array(QuizQuestionModel.mocks.prefix(3))
            ),
            QuizModel(
                quizId: "quiz2",
                name: "Science Basics",
                color: .blue,
                sourceText: "Basic science concepts",
                createdAt: now.addingTimeInterval(-86400),
                questions: [QuizQuestionModel.mocks[3]]
            ),
            QuizModel(
                quizId: "quiz3",
                name: "Empty Quiz",
                color: .green,
                sourceText: "A quiz with no questions yet",
                createdAt: now.addingTimeInterval(-172800),
                questions: []
            )
        ]
    }
}
