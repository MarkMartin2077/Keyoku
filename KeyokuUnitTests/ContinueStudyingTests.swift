//
//  ContinueStudyingTests.swift
//  KeyokuUnitTests
//

// Tests that starting a practice session stamps lastStudiedAt on the deck:
//
//  - onPracticePressed (small decks start immediately) stamps lastStudiedAt = Date()
//
// (The HomePresenter.studiedDecks "Continue Studying" section was removed in
// 73ef0a4 and replaced by dueDecks / stillLearningCards, so its tests were dropped.)
//
// All tests use lightweight in-memory mocks — no Firebase or simulator needed.

import Testing
@testable import Keyoku
import SwiftfulGamification
import Foundation

// MARK: - Private Mock Types

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
    var generationAvailability: GenerationAvailability { .unavailable(.deviceNotEligible) }
    func prewarmGeneration() {}
    func generateFlashcards(from text: String, count: Int, avoiding existingQuestions: [String]) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { $0.finish(throwing: GenerationFailure.modelUnavailable) }
    }
    func extractPDFText(from url: URL) async throws -> (text: String, pageCount: Int) {
        throw PDFExtractionError.unreadable
    }
    func quizzes(forDeckId deckId: String) -> [QuizModel] { [] }
    func deleteQuiz(id: String) throws {}
    var quizGenerationAvailability: GenerationAvailability { .unavailable(.deviceNotEligible) }
    func prewarmQuizGeneration() {}
    func canMakeQuiz(sourceLength: Int) -> Bool { QuizQuestionCount.canMakeQuiz(sourceLength: sourceLength) }
    func maxQuizQuestionCount(sourceLength: Int) -> Int { QuizQuestionCount.maximum(sourceLength: sourceLength) }
    func defaultQuizQuestionCount(sourceLength: Int) -> Int { QuizQuestionCount.defaultCount(sourceLength: sourceLength) }
    func generateQuiz(
        for deck: DeckModel,
        questionCount: Int,
        onProgress: @escaping @MainActor (QuizGenerationProgress) -> Void
    ) async throws -> QuizModel {
        throw QuizGenerationError.generation(.modelUnavailable)
    }

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
    func showPracticeView(deck: DeckModel, cardLimit: Int?) {}
    func showReviewDueView(deck: DeckModel) {}
    func showQuizPlayView(quiz: QuizModel, deckColor: DeckColor) {}
    func showDeleteQuizAlert(quizTitle: String, onDeletePressed: @escaping @MainActor @Sendable () -> Void) {}
    func showSimpleAlert(title: String, subtitle: String?) {}
}

// MARK: - Helpers

private func unlearnedCard(deckId: String) -> FlashcardModel {
    FlashcardModel(question: "Q", answer: "A", deckId: deckId, isLearned: false)
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
