//
//  WidgetDataBridge.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import WidgetKit

enum WidgetDataBridge {

    static func update(decks: [DeckModel]) {
        let recentDecks = decks
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map { deck in
                WidgetDeckItem(
                    id: deck.deckId,
                    name: deck.name,
                    colorRawValue: deck.color.rawValue,
                    cardCount: deck.flashcards.count,
                    createdAt: deck.createdAt
                )
            }

        let totalCards = decks.reduce(0) { $0 + $1.flashcards.count }

        let widgetData = WidgetData(
            deckCount: decks.count,
            totalCardCount: totalCards,
            recentDecks: Array(recentDecks),
            updatedAt: .now
        )

        WidgetDataStore.save(widgetData)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear() {
        WidgetDataStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
