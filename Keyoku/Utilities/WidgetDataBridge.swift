//
//  WidgetDataBridge.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import WidgetKit

enum WidgetDataBridge {

    static func update(decks: [DeckModel], quizzes: [QuizModel]) {
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

        let recentQuizzes = quizzes
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map { quiz in
                WidgetQuizItem(
                    id: quiz.quizId,
                    name: quiz.name,
                    colorRawValue: quiz.color.rawValue,
                    questionCount: quiz.questions.count,
                    createdAt: quiz.createdAt
                )
            }

        let totalCards = decks.reduce(0) { $0 + $1.flashcards.count }

        let widgetData = WidgetData(
            deckCount: decks.count,
            totalCardCount: totalCards,
            quizCount: quizzes.count,
            recentDecks: Array(recentDecks),
            recentQuizzes: Array(recentQuizzes),
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
