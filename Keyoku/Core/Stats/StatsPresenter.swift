//
//  StatsPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

struct DeckStat: Identifiable {
    let deckId: String
    let name: String
    let color: DeckColor
    let totalCards: Int
    let learnedCards: Int
    let dueCards: Int

    var id: String { deckId }
}

struct DueDayItem: Identifiable {
    let date: Date
    let count: Int

    var id: Date { date }
}

/// Stats presenter that aggregates SRS and study data across all decks for the Insights tab.
///
/// Computes per-deck and aggregate metrics: streak, learned count, retention rate,
/// due-today count, and a 7-day due-card forecast used for the bar chart.
@Observable
@MainActor
class StatsPresenter {

    let interactor: any StatsInteractor
    let router: any StatsRouter

    init(interactor: any StatsInteractor, router: any StatsRouter) {
        self.interactor = interactor
        self.router = router
    }

    // MARK: - Computed Stats

    private var allCards: [FlashcardModel] {
        interactor.decks.flatMap(\.flashcards)
    }

    var totalCards: Int { allCards.count }

    var totalDecks: Int { interactor.decks.count }

    var learnedCards: Int { allCards.filter(\.isLearned).count }

    private var reviewedCards: Int {
        allCards.filter { $0.dueDate != nil }.count
    }

    var dueToday: Int {
        let now = Date()
        return allCards.filter { card in
            guard let due = card.dueDate else { return false }
            return due <= now
        }.count
    }

    /// Learned / reviewed. Nil if no cards have been reviewed yet.
    var retentionRate: Double? {
        guard reviewedCards > 0 else { return nil }
        return Double(learnedCards) / Double(reviewedCards)
    }

    var currentStreak: Int {
        interactor.currentStreakData.currentStreak ?? 0
    }

    // MARK: - 7-Day Due Forecast

    /// Count of cards due on each of the next 7 days.
    /// Day 0 (today) includes all overdue cards. Future days show cards scheduled for that day.
    var dueByDay: [DueDayItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).map { dayOffset in
            let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: today)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let count: Int
            if dayOffset == 0 {
                // Today: overdue + due today
                count = allCards.filter { card in
                    guard let due = card.dueDate else { return false }
                    return due < dayEnd
                }.count
            } else {
                // Future: cards scheduled specifically for that day
                count = allCards.filter { card in
                    guard let due = card.dueDate else { return false }
                    return due >= dayStart && due < dayEnd
                }.count
            }

            return DueDayItem(date: dayStart, count: count)
        }
    }

    // MARK: - Per-Deck Stats

    var perDeckStats: [DeckStat] {
        interactor.decks.map { deck in
            let cards = deck.flashcards
            let learned = cards.filter(\.isLearned).count
            let due = cards.filter { card in
                guard let dueDate = card.dueDate else { return false }
                return dueDate <= Date()
            }.count
            return DeckStat(
                deckId: deck.deckId,
                name: deck.name,
                color: deck.color,
                totalCards: cards.count,
                learnedCards: learned,
                dueCards: due
            )
        }
        .sorted { $0.totalCards > $1.totalCards }
    }

    // MARK: - Lifecycle

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }
}

// MARK: - Analytics Events

extension StatsPresenter {
    enum Event: LoggableEvent {
        case onAppear

        var eventName: String { "StatsView_Appear" }
        var parameters: [String: Any]? { nil }
        var type: LogType { .analytic }
    }
}
