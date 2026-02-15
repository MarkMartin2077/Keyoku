//
//  WidgetData.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation

// MARK: - Shared Models

struct WidgetDeckItem: Codable, Identifiable {
    let id: String
    let name: String
    let colorRawValue: String
    let cardCount: Int
    let createdAt: Date
}

struct WidgetQuizItem: Codable, Identifiable {
    let id: String
    let name: String
    let colorRawValue: String
    let questionCount: Int
    let createdAt: Date
}

struct WidgetData: Codable {
    let deckCount: Int
    let totalCardCount: Int
    let quizCount: Int
    let recentDecks: [WidgetDeckItem]
    let recentQuizzes: [WidgetQuizItem]
    let updatedAt: Date

    static let empty = WidgetData(
        deckCount: 0,
        totalCardCount: 0,
        quizCount: 0,
        recentDecks: [],
        recentQuizzes: [],
        updatedAt: .now
    )

    static let placeholder = WidgetData(
        deckCount: 3,
        totalCardCount: 42,
        quizCount: 2,
        recentDecks: [
            WidgetDeckItem(
                id: "p1",
                name: "Japanese Basics",
                colorRawValue: "red",
                cardCount: 18,
                createdAt: .now
            ),
            WidgetDeckItem(
                id: "p2",
                name: "Math Fundamentals",
                colorRawValue: "blue",
                cardCount: 12,
                createdAt: .now.addingTimeInterval(-86400)
            ),
            WidgetDeckItem(
                id: "p3",
                name: "History 101",
                colorRawValue: "green",
                cardCount: 12,
                createdAt: .now.addingTimeInterval(-172800)
            )
        ],
        recentQuizzes: [
            WidgetQuizItem(
                id: "q1",
                name: "World Geography",
                colorRawValue: "purple",
                questionCount: 15,
                createdAt: .now
            ),
            WidgetQuizItem(
                id: "q2",
                name: "Science Basics",
                colorRawValue: "orange",
                questionCount: 10,
                createdAt: .now.addingTimeInterval(-86400)
            ),
            WidgetQuizItem(
                id: "q3",
                name: "Vocabulary",
                colorRawValue: "teal",
                questionCount: 20,
                createdAt: .now.addingTimeInterval(-172800)
            )
        ],
        updatedAt: .now
    )
}

// MARK: - Data Store

enum WidgetDataStore {
    private static let suiteName = "group.com.markmartin89.Keyoku"
    private static let key = "widget_data"

    static func save(_ data: WidgetData) {
        guard let suite = UserDefaults(suiteName: suiteName) else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            suite.set(encoded, forKey: key)
        }
    }

    static func load() -> WidgetData {
        guard let suite = UserDefaults(suiteName: suiteName),
              let data = suite.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .empty
        }
        return decoded
    }

    static func clear() {
        guard let suite = UserDefaults(suiteName: suiteName) else { return }
        suite.removeObject(forKey: key)
    }
}
