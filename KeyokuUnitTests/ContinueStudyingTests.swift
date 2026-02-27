//
//  ContinueStudyingTests.swift
//  KeyokuUnitTests
//

// Tests for the "Continue Studying" section (Option C implementation):
//
//  1. studiedDecks only shows decks where:
//     - lastStudiedAt is non-nil (user has started a practice session)
//     - at least one flashcard is still unlearned
//  2. studiedDecks sorts by most recently studied (newest first)
//  3. onPracticePressed stamps lastStudiedAt = Date() on the deck
//
// All tests use lightweight in-memory mocks — no Firebase or simulator needed.

import Testing
@testable import Keyoku
import SwiftfulGamification
import Foundation

// MARK: - Private Mock Types

@MainActor
private class MockHomeInteractor: HomeInteractor {

    var decks: [DeckModel]

    init(decks: [DeckModel]) {
        self.decks = decks
    }

    func loadDecks() {}
    func getDeck(id: String) -> DeckModel? { decks.first { $0.deckId == id } }
    func updateDeck(_ deck: DeckModel) throws {
        if let index = decks.firstIndex(where: { $0.deckId == deck.deckId }) {
            decks[index] = deck
        }
    }
    func schedulePushNotificationsForTheNextWeek() {}
    func requestPushAuthorization() async throws -> Bool { false }
    func canRequestPushAuthorization() async -> Bool { false }
    func parseSpotlightIdentifier(_ identifier: String) -> (type: String, id: String)? { nil }

    var currentUser: UserModel? { nil }
    var isPremium: Bool { false }
    var currentStreakData: CurrentStreakData {
        StreakManager(
            services: MockStreakServices(streak: nil),
            configuration: StreakConfiguration(
                streakKey: "test",
                eventsRequiredPerDay: 1,
                useServerCalculation: false,
                leewayHours: 0,
                freezeBehavior: .autoConsumeFreezes
            ),
            logger: nil
        ).currentStreakData
    }

    // GlobalInteractor
    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType) {}
    func trackEvent(event: AnyLoggableEvent) {}
    func trackEvent(event: LoggableEvent) {}
    func trackScreenEvent(event: LoggableEvent) {}
    func playHaptic(option: HapticOption) {}
}

@MainActor
private struct MockHomeRouter: HomeRouter {
    var router: AnyRouter { fatalError("router not accessed in these tests") }
    func showDevSettingsView() {}
    func showDeckDetailView(deck: DeckModel) {}
    func showCreateContentView(onDismiss: (() -> Void)?) {}
    func showDecksView(delegate: DecksDelegate) {}
    func showPaywallView(delegate: PaywallDelegate) {}
}

@MainActor
private class MockDeckDetailInteractor: DeckDetailInteractor {

    private var deckStore: [String: DeckModel]
    private(set) var lastUpdatedDeck: DeckModel?

    init(deck: DeckModel) {
        deckStore = [deck.deckId: deck]
    }

    func getDeck(id: String) -> DeckModel? { deckStore[id] }
    func updateDeck(_ deck: DeckModel) throws {
        deckStore[deck.deckId] = deck
        lastUpdatedDeck = deck
    }
    func addFlashcard(question: String, answer: String, toDeckId: String) throws {}
    func deleteFlashcard(id: String, fromDeckId: String) throws {}
    func saveDeckImage(data: Data) throws -> String { "" }

    // GlobalInteractor
    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType) {}
    func trackEvent(event: AnyLoggableEvent) {}
    func trackEvent(event: LoggableEvent) {}
    func trackScreenEvent(event: LoggableEvent) {}
    func playHaptic(option: HapticOption) {}
}

@MainActor
private struct MockDeckDetailRouter: DeckDetailRouter {
    var router: AnyRouter { fatalError("router not accessed in these tests") }
    func showPracticeView(deck: DeckModel) {}
}

// MARK: - Helpers

private func unlearnedCard(deckId: String) -> FlashcardModel {
    FlashcardModel(question: "Q", answer: "A", deckId: deckId, isLearned: false)
}

private func learnedCard(deckId: String) -> FlashcardModel {
    FlashcardModel(question: "Q", answer: "A", deckId: deckId, isLearned: true)
}

// MARK: - studiedDecks Filtering Tests

@Suite("Continue Studying — studiedDecks filtering")
@MainActor
struct StudiedDecksFilterTests {

    private func makePresenter(decks: [DeckModel]) -> HomePresenter {
        HomePresenter(interactor: MockHomeInteractor(decks: decks), router: MockHomeRouter())
    }

    @Test("Deck with nil lastStudiedAt is excluded even with unlearned cards")
    func neverStudiedDeckExcluded() {
        // GIVEN — a deck that was never practiced (lastStudiedAt is nil)
        let deck = DeckModel(
            deckId: "d1",
            name: "Test",
            sourceText: "text",
            flashcards: [unlearnedCard(deckId: "d1")]
        ) // lastStudiedAt defaults to nil

        // THEN — it should not appear in Continue Studying
        #expect(makePresenter(decks: [deck]).studiedDecks.isEmpty)
    }

    @Test("Deck with all cards learned is excluded even when lastStudiedAt is set")
    func fullyLearnedDeckExcluded() {
        // GIVEN — a deck that has been practiced but every card is learned
        let deck = DeckModel(
            deckId: "d1",
            name: "Test",
            sourceText: "text",
            flashcards: [learnedCard(deckId: "d1")],
            lastStudiedAt: Date()
        )

        // THEN — nothing left to study, so it should not appear
        #expect(makePresenter(decks: [deck]).studiedDecks.isEmpty)
    }

    @Test("Deck with lastStudiedAt set and unlearned cards appears in studiedDecks")
    func practisedDeckIncluded() {
        // GIVEN — a deck that has been practiced and still has unlearned cards
        let deck = DeckModel(
            deckId: "d1",
            name: "Test",
            sourceText: "text",
            flashcards: [unlearnedCard(deckId: "d1")],
            lastStudiedAt: Date()
        )

        // THEN — it should appear exactly once
        let studied = makePresenter(decks: [deck]).studiedDecks
        #expect(studied.count == 1)
        #expect(studied[0].deckId == "d1")
    }

    @Test("Only the practised deck with unlearned cards appears in a mixed list")
    func mixedDecksFiltered() {
        // GIVEN — three decks: one good, one never studied, one fully learned
        let now = Date()
        let good = DeckModel(
            deckId: "good",
            name: "Good",
            sourceText: "text",
            flashcards: [unlearnedCard(deckId: "good")],
            lastStudiedAt: now
        )
        let neverStudied = DeckModel(
            deckId: "never",
            name: "Never",
            sourceText: "text",
            flashcards: [unlearnedCard(deckId: "never")]
            // lastStudiedAt: nil (default)
        )
        let allLearned = DeckModel(
            deckId: "done",
            name: "Done",
            sourceText: "text",
            flashcards: [learnedCard(deckId: "done")],
            lastStudiedAt: now
        )

        // THEN — only the good deck passes both filters
        let studied = makePresenter(decks: [good, neverStudied, allLearned]).studiedDecks
        #expect(studied.count == 1)
        #expect(studied[0].deckId == "good")
    }

    @Test("studiedDecks sorts by most recently studied first")
    func sortedByRecency() {
        // GIVEN — three decks studied at different times, given in non-sorted order
        let now = Date()
        let oldest = DeckModel(
            deckId: "oldest",
            name: "Oldest",
            sourceText: "text",
            flashcards: [unlearnedCard(deckId: "oldest")],
            lastStudiedAt: now.addingTimeInterval(-7200) // 2 hours ago
        )
        let newest = DeckModel(
            deckId: "newest",
            name: "Newest",
            sourceText: "text",
            flashcards: [unlearnedCard(deckId: "newest")],
            lastStudiedAt: now // just now
        )
        let middle = DeckModel(
            deckId: "middle",
            name: "Middle",
            sourceText: "text",
            flashcards: [unlearnedCard(deckId: "middle")],
            lastStudiedAt: now.addingTimeInterval(-3600) // 1 hour ago
        )

        // Array order is oldest → middle → newest to prove it's not just passthrough
        let studied = makePresenter(decks: [oldest, middle, newest]).studiedDecks

        // THEN — sorted newest first
        #expect(studied.count == 3)
        #expect(studied[0].deckId == "newest")
        #expect(studied[1].deckId == "middle")
        #expect(studied[2].deckId == "oldest")
    }

    @Test("Deck with mixed learned/unlearned cards appears when lastStudiedAt is set")
    func partiallyLearnedDeckIncluded() {
        // GIVEN — a deck where some cards are learned but at least one is not
        let deck = DeckModel(
            deckId: "partial",
            name: "Partial",
            sourceText: "text",
            flashcards: [
                learnedCard(deckId: "partial"),
                unlearnedCard(deckId: "partial")
            ],
            lastStudiedAt: Date()
        )

        // THEN — it should appear because there's still work to do
        let studied = makePresenter(decks: [deck]).studiedDecks
        #expect(studied.count == 1)
        #expect(studied[0].deckId == "partial")
    }
}

// MARK: - Practice Stamp Tests

@Suite("Continue Studying — onPracticePressed stamps lastStudiedAt")
@MainActor
struct PracticeStampTests {

    @Test("onPracticePressed saves deck with a non-nil lastStudiedAt")
    func practiceStampsDate() {
        // GIVEN — a deck that was never practiced
        let deck = DeckModel(
            deckId: "d1",
            name: "Test",
            sourceText: "text",
            flashcards: [unlearnedCard(deckId: "d1")]
            // lastStudiedAt: nil (default)
        )
        let interactor = MockDeckDetailInteractor(deck: deck)
        let presenter = DeckDetailPresenter(
            interactor: interactor,
            router: MockDeckDetailRouter(),
            deck: deck
        )

        // WHEN — the user taps Practice
        presenter.onPracticePressed()

        // THEN — the saved deck has a timestamp
        #expect(interactor.lastUpdatedDeck != nil)
        #expect(interactor.lastUpdatedDeck?.lastStudiedAt != nil)
    }

    @Test("onPracticePressed updates a previously set lastStudiedAt to a more recent date")
    func practiceRefreshesStamp() throws {
        // GIVEN — a deck studied one day ago
        let yesterday = Date().addingTimeInterval(-86400)
        let deck = DeckModel(
            deckId: "d1",
            name: "Test",
            sourceText: "text",
            flashcards: [unlearnedCard(deckId: "d1")],
            lastStudiedAt: yesterday
        )
        let interactor = MockDeckDetailInteractor(deck: deck)
        let presenter = DeckDetailPresenter(
            interactor: interactor,
            router: MockDeckDetailRouter(),
            deck: deck
        )

        // WHEN — the user taps Practice again today
        presenter.onPracticePressed()

        // THEN — the stamp is newer than yesterday
        let savedDate = try #require(interactor.lastUpdatedDeck?.lastStudiedAt)
        #expect(savedDate > yesterday)
    }

    @Test("onPracticePressed preserves all flashcards when stamping")
    func practiceStampPreservesCards() {
        // GIVEN — a deck with two cards
        let deck = DeckModel(
            deckId: "d1",
            name: "Test",
            sourceText: "text",
            flashcards: [
                FlashcardModel(question: "Q1", answer: "A1", deckId: "d1"),
                FlashcardModel(question: "Q2", answer: "A2", deckId: "d1", isLearned: true)
            ]
        )
        let interactor = MockDeckDetailInteractor(deck: deck)
        let presenter = DeckDetailPresenter(
            interactor: interactor,
            router: MockDeckDetailRouter(),
            deck: deck
        )

        // WHEN
        presenter.onPracticePressed()

        // THEN — all cards are preserved in the saved deck
        #expect(interactor.lastUpdatedDeck?.flashcards.count == 2)
    }
}
