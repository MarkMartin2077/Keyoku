//
//  QuizModel.swift
//  Keyoku
//

import Foundation
import IdentifiableByString

/// A saved, titled set of multiple-choice questions generated from one deck's source text.
///
/// Stored flat beside decks (ADR 0003): it points at its deck by `deckId` only,
/// and holds its questions and attempts inline.
struct QuizModel: StringIdentifiable, Codable, Sendable, Hashable {
    let id: String
    let deckId: String
    let title: String
    let createdAt: Date
    let questions: [QuizQuestionModel]
    let attempts: [QuizAttemptModel]

    init(
        id: String = UUID().uuidString,
        deckId: String,
        title: String,
        createdAt: Date = .now,
        questions: [QuizQuestionModel],
        attempts: [QuizAttemptModel] = []
    ) {
        self.id = id
        self.deckId = deckId
        self.title = title
        self.createdAt = createdAt
        self.questions = questions
        self.attempts = attempts
    }

    /// Highest score across all attempts, or `nil` if the quiz has never been played.
    /// Derived on read and never stored.
    var bestScore: Int? {
        attempts.map(\.score).max()
    }

    /// Returns a copy of this quiz with `attempt` appended.
    func appendingAttempt(_ attempt: QuizAttemptModel) -> QuizModel {
        QuizModel(
            id: id,
            deckId: deckId,
            title: title,
            createdAt: createdAt,
            questions: questions,
            attempts: attempts + [attempt]
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case deckId = "deck_id"
        case title
        case createdAt = "created_at"
        case questions
        case attempts
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "quiz_\(CodingKeys.id.rawValue)": id,
            "quiz_\(CodingKeys.deckId.rawValue)": deckId,
            "quiz_\(CodingKeys.title.rawValue)": title,
            "quiz_\(CodingKeys.createdAt.rawValue)": createdAt,
            "quiz_question_count": questions.count,
            "quiz_attempt_count": attempts.count,
            "quiz_best_score": bestScore
        ]
        return dict.compactMapValues({ $0 })
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        let now = Date()
        return [
            QuizModel(
                id: "quiz1",
                deckId: "deck1",
                title: "Spanish Greetings Quiz",
                createdAt: now.addingTimeInterval(-7200),
                questions: QuizQuestionModel.mocks,
                attempts: QuizAttemptModel.mocks
            ),
            QuizModel(
                id: "quiz2",
                deckId: "deck2",
                title: "Biology 101 Quiz",
                createdAt: now.addingTimeInterval(-172800),
                questions: Array(QuizQuestionModel.mocks.prefix(3))
            )
        ]
    }
}
