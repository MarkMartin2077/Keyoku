//
//  DeckDetailGenerateCardsPresenterTests.swift
//  KeyokuUnitTests
//

// Tests for generating more cards on the deck screen: what the saved deck keeps.
// Uses in-memory mocks — no Foundation Models, Firebase or simulator UI needed.

import Testing
@testable import Keyoku
import Foundation

// MARK: - Mocks

@MainActor
private final class MockGenerateCardsDeckInteractor: DeckDetailInteractor {

    let mockLog = MockLogService()
    var deck: DeckModel
    /// The cards each generation run streams back as one completed batch.
    var generatedCards: [FlashcardModel] = [FlashcardModel(question: "New Q", answer: "New A", deckId: "deck1")]

    init(deck: DeckModel) {
        self.deck = deck
    }

    // Deck & flashcards
    func getDeck(id: String) -> DeckModel? { id == deck.deckId ? deck : nil }
    func addFlashcard(question: String, answer: String, toDeckId: String) throws {}
    func deleteFlashcard(id: String, fromDeckId: String) throws {}
    func updateDeck(_ deck: DeckModel) throws { self.deck = deck }
    func saveDeckImage(data: Data) throws -> String { "" }
    var generationAvailability: GenerationAvailability { .available(.onDevice) }
    func prewarmGeneration() {}
    func generateFlashcards(from text: String, count: Int, avoiding existingQuestions: [String]) -> AsyncThrowingStream<GenerationEvent, Error> {
        let cards = generatedCards
        return AsyncThrowingStream { continuation in
            continuation.yield(.started(model: .onDevice, batchCount: 1))
            continuation.yield(.batchCompleted(batch: 0, cards: cards))
            continuation.finish()
        }
    }
    func extractPDFText(from url: URL) async throws -> (text: String, pageCount: Int) {
        throw PDFExtractionError.unreadable
    }

    // Quizzes (unused here)
    func quizzes(forDeckId deckId: String) -> [QuizModel] { [] }
    func deleteQuiz(id: String) throws {}
    var quizGenerationAvailability: GenerationAvailability { .available(.onDevice) }
    func prewarmQuizGeneration() {}
    func canMakeQuiz(sourceLength: Int) -> Bool { QuizQuestionCount.canMakeQuiz(sourceLength: sourceLength) }
    var minQuizQuestionCount: Int { QuizQuestionCount.minimum }
    var minQuizSourceLength: Int { QuizQuestionCount.minimumSourceLength }
    func maxQuizQuestionCount(sourceLength: Int) -> Int { QuizQuestionCount.maximum(sourceLength: sourceLength) }
    func defaultQuizQuestionCount(sourceLength: Int) -> Int { QuizQuestionCount.defaultCount(sourceLength: sourceLength) }
    func generateQuiz(
        for deck: DeckModel,
        questionCount: Int,
        onProgress: @escaping @MainActor (QuizGenerationProgress) -> Void
    ) async throws -> QuizModel {
        throw QuizGenerationError.generation(.cancelled)
    }

    // GlobalInteractor
    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType) {
        mockLog.trackEvent(event: AnyLoggableEvent(eventName: eventName, parameters: parameters, type: type))
    }
    func trackEvent(event: AnyLoggableEvent) { mockLog.trackEvent(event: event) }
    func trackEvent(event: LoggableEvent) { mockLog.trackEvent(event: event) }
    func trackScreenEvent(event: LoggableEvent) { mockLog.trackScreenView(event: event) }
    func playHaptic(option: HapticOption) {}
}

@MainActor
private final class MockGenerateCardsDeckRouter: DeckDetailRouter {
    var router: AnyRouter { fatalError("router not accessed in these tests") }

    private(set) var simpleAlerts: [(title: String, subtitle: String?)] = []

    func showPracticeView(deck: DeckModel, cardLimit: Int?) {}
    func showReviewDueView(deck: DeckModel) {}
    func showQuizPlayView(quiz: QuizModel, deckColor: DeckColor) {}
    func showDeleteQuizAlert(quizTitle: String, onDeletePressed: @escaping @MainActor @Sendable () -> Void) {}
    func showSimpleAlert(title: String, subtitle: String?) {
        simpleAlerts.append((title, subtitle))
    }
}

// MARK: - Helpers

@MainActor
private struct Harness {
    let presenter: DeckDetailPresenter
    let interactor: MockGenerateCardsDeckInteractor
    let router: MockGenerateCardsDeckRouter
}

@MainActor
private func makeHarness(deckSourceText: String) -> Harness {
    let deck = DeckModel(
        deckId: "deck1",
        name: "Biology",
        color: .green,
        sourceText: deckSourceText,
        flashcards: [FlashcardModel(question: "Old Q", answer: "Old A", deckId: "deck1")]
    )
    let interactor = MockGenerateCardsDeckInteractor(deck: deck)
    let router = MockGenerateCardsDeckRouter()
    let presenter = DeckDetailPresenter(interactor: interactor, router: router, deck: deck)
    return Harness(presenter: presenter, interactor: interactor, router: router)
}

/// Opens the sheet, pastes `text`, generates, and waits for the run to finish.
@MainActor
private func generateCards(_ harness: Harness, from text: String) async {
    harness.presenter.onGenerateSheetOpened()
    harness.presenter.sourceText = text
    harness.presenter.onGenerateCardsPressed()
    for _ in 0..<200 where !harness.presenter.isGenerationComplete && harness.router.simpleAlerts.isEmpty {
        await Task.yield()
    }
}

private let originalText = "Mitochondria are the powerhouse of the cell. " + String(repeating: "Cells make energy. ", count: 20)
private let newText = "Photosynthesis turns light into chemical energy. " + String(repeating: "Plants use chlorophyll. ", count: 20)

// MARK: - Source Text

@Suite("DeckDetail Generate Cards — Source text")
@MainActor
struct DeckDetailGenerateCardsSourceTextTests {

    @Test("Generating more cards keeps the deck's source text and adds the new text")
    func newTextIsAddedToExistingSourceText() async {
        let harness = makeHarness(deckSourceText: originalText)

        await generateCards(harness, from: newText)

        #expect(harness.presenter.isGenerationComplete)
        #expect(harness.interactor.deck.flashcards.count == 2)
        #expect(harness.interactor.deck.sourceText.contains(originalText))
        #expect(harness.interactor.deck.sourceText.contains(newText))
    }

    @Test("Generating cards for a deck without source text saves the new text as its source text")
    func newTextBecomesSourceTextWhenDeckHasNone() async {
        let harness = makeHarness(deckSourceText: "")

        await generateCards(harness, from: newText)

        #expect(harness.presenter.isGenerationComplete)
        #expect(harness.interactor.deck.sourceText == newText)
    }

    @Test("Generating again from text the deck already has doesn't duplicate it")
    func sameTextIsNotDuplicated() async {
        let harness = makeHarness(deckSourceText: originalText)

        await generateCards(harness, from: originalText)

        #expect(harness.presenter.isGenerationComplete)
        #expect(harness.interactor.deck.sourceText == originalText)
    }
}
