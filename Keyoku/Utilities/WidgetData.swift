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

struct WidgetData: Codable {
    let deckCount: Int
    let totalCardCount: Int
    let recentDecks: [WidgetDeckItem]
    let updatedAt: Date

    static let empty = WidgetData(
        deckCount: 0,
        totalCardCount: 0,
        recentDecks: [],
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
