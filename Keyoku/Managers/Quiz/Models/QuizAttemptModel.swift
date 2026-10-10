//
//  QuizAttemptModel.swift
//  Keyoku
//

import Foundation

/// One finished play-through of a quiz. Stored inside its `QuizModel`;
/// recording an attempt rewrites the whole quiz.
struct QuizAttemptModel: Codable, Sendable, Hashable {
    let date: Date
    let score: Int
    let total: Int

    init(date: Date = .now, score: Int, total: Int) {
        self.date = date
        self.score = score
        self.total = total
    }

    enum CodingKeys: String, CodingKey {
        case date
        case score
        case total
    }

    var eventParameters: [String: Any] {
        [
            "attempt_\(CodingKeys.date.rawValue)": date,
            "attempt_\(CodingKeys.score.rawValue)": score,
            "attempt_\(CodingKeys.total.rawValue)": total
        ]
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        let now = Date()
        return [
            QuizAttemptModel(date: now.addingTimeInterval(-3600), score: 3, total: 5),
            QuizAttemptModel(date: now.addingTimeInterval(-86400), score: 4, total: 5)
        ]
    }
}
