//
//  DeckDetailQuizzesPresenterTests.swift
//  KeyokuUnitTests
//

// Tests for the Quizzes section on the deck screen: which state the section is in,
// the New Quiz sheet's question count, making a quiz (success, failure, cancel),
// deleting after confirmation, opening a quiz, and analytics for every new action.
// Uses in-memory mocks — no Foundation Models, Firebase or simulator UI needed.

import Testing
@testable import Keyoku
import Foundation

// MARK: - Mocks

@MainActor
private final class MockQuizDeckInteractor: DeckDetailInteractor {

    let mockLog = MockLogService()
    var deck: DeckModel
    private(set) var storedQuizzes: [QuizModel]
    private(set) var deletedQuizIds: [String] = []
    private(set) var prewarmCount = 0
    var availability: GenerationAvailability = .available(.onDevice)

    /// What `generateQuiz` does once it's released: save a quiz with this many questions, or throw.
    var generationResult: Result<Int, Error> = .success(6)
    var deleteError: Error?
    /// When true, `generateQuiz` reports progress and then waits for `releaseGeneration()`.
    var holdsGeneration = false
    /// When true, `generateQuiz` saves even if its task was cancelled (the post-save cancel window).
    var savesWhenCancelled = false
    private var gates: [CheckedContinuation<Void, Never>] = []
    var isWaitingAtGate: Bool { !gates.isEmpty }
    var runsWaitingAtGate: Int { gates.count }
    /// The progress callback of every run, in start order.
    private(set) var progressHandlers: [@MainActor (QuizGenerationProgress) -> Void] = []

    init(deck: DeckModel, quizzes: [QuizModel] = []) {
        self.deck = deck
        self.storedQuizzes = quizzes
    }

    func replaceQuiz(_ quiz: QuizModel) {
        storedQuizzes = storedQuizzes.map { $0.id == quiz.id ? quiz : $0 }
    }

    /// Releases every run waiting at the gate.
    func releaseGeneration() {
        let waiting = gates
        gates = []
        waiting.forEach { $0.resume() }
    }

    // Quizzes
    func quizzes(forDeckId deckId: String) -> [QuizModel] {
        storedQuizzes.filter { $0.deckId == deckId }
    }

    func deleteQuiz(id: String) throws {
        if let deleteError { throw deleteError }
        deletedQuizIds.append(id)
        storedQuizzes.removeAll { $0.id == id }
    }

    var quizGenerationAvailability: GenerationAvailability { availability }
    func prewarmQuizGeneration() { prewarmCount += 1 }
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
        progressHandlers.append(onProgress)
        onProgress(QuizGenerationProgress(generatedCount: 3, totalCount: questionCount))
        if holdsGeneration {
            await withCheckedContinuation { gates.append($0) }
        }
        // Mirrors CoreInteractor: a cancelled run saves nothing.
        if Task.isCancelled && !savesWhenCancelled {
            throw QuizGenerationError.generation(.cancelled)
        }
        switch generationResult {
        case .failure(let error):
            throw error
        case .success(let count):
            let quiz = QuizModel(
                deckId: deck.deckId,
                title: "\(deck.name) Quiz",
                questions: Array(repeating: QuizQuestionModel.mock, count: count)
            )
            storedQuizzes.insert(quiz, at: 0)
            return quiz
        }
    }

    // Deck & flashcards (unused here)
    func getDeck(id: String) -> DeckModel? { id == deck.deckId ? deck : nil }
    func addFlashcard(question: String, answer: String, toDeckId: String) throws {}
    func deleteFlashcard(id: String, fromDeckId: String) throws {}
    func updateDeck(_ deck: DeckModel) throws { self.deck = deck }
    func saveDeckImage(data: Data) throws -> String { "" }
    var generationAvailability: GenerationAvailability { availability }
    func prewarmGeneration() {}
    func generateFlashcards(from text: String, count: Int, avoiding existingQuestions: [String]) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func extractPDFText(from url: URL) async throws -> (text: String, pageCount: Int) {
        throw PDFExtractionError.unreadable
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
private final class MockQuizDeckRouter: DeckDetailRouter {
    var router: AnyRouter { fatalError("router not accessed in these tests") }

    private(set) var playedQuizzes: [(quiz: QuizModel, deckColor: DeckColor)] = []
    private(set) var deleteAlertTitles: [String] = []
    private(set) var onDeletePressed: (@MainActor @Sendable () -> Void)?
    private(set) var simpleAlerts: [(title: String, subtitle: String?)] = []

    func showPracticeView(deck: DeckModel, cardLimit: Int?) {}
    func showReviewDueView(deck: DeckModel) {}

    func showQuizPlayView(quiz: QuizModel, deckColor: DeckColor) {
        playedQuizzes.append((quiz, deckColor))
    }

    func showDeleteQuizAlert(quizTitle: String, onDeletePressed: @escaping @MainActor @Sendable () -> Void) {
        deleteAlertTitles.append(quizTitle)
        self.onDeletePressed = onDeletePressed
    }

    func showSimpleAlert(title: String, subtitle: String?) {
        simpleAlerts.append((title, subtitle))
    }
}

// MARK: - Helpers

@MainActor
private struct Harness {
    let presenter: DeckDetailPresenter
    let interactor: MockQuizDeckInteractor
    let router: MockQuizDeckRouter
}

private func makeDeck(sourceLength: Int, sourceText: String? = nil) -> DeckModel {
    DeckModel(
        deckId: "deck1",
        name: "Biology",
        color: .green,
        sourceText: sourceText ?? String(repeating: "a", count: sourceLength),
        flashcards: [FlashcardModel(question: "Q", answer: "A", deckId: "deck1")]
    )
}

@MainActor
private func makeHarness(
    sourceLength: Int = 3_000,
    sourceText: String? = nil,
    quizzes: [QuizModel] = [],
    availability: GenerationAvailability = .available(.onDevice)
) -> Harness {
    let deck = makeDeck(sourceLength: sourceLength, sourceText: sourceText)
    let interactor = MockQuizDeckInteractor(deck: deck, quizzes: quizzes)
    interactor.availability = availability
    let router = MockQuizDeckRouter()
    let presenter = DeckDetailPresenter(interactor: interactor, router: router, deck: deck)
    return Harness(presenter: presenter, interactor: interactor, router: router)
}

private func savedQuiz(id: String, title: String = "Saved Quiz") -> QuizModel {
    QuizModel(id: id, deckId: "deck1", title: title, questions: QuizQuestionModel.mocks)
}

/// Yields to let the generation task run until `condition` holds.
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<200 where !condition() {
        await Task.yield()
    }
}

// MARK: - Section State

@Suite("DeckDetail Quizzes — Section state")
@MainActor
struct DeckDetailQuizSectionStateTests {

    @Test("A deck with saved quizzes shows the strip, newest first, led by a ready + card")
    func stripWithQuizzes() {
        let harness = makeHarness(quizzes: [savedQuiz(id: "new"), savedQuiz(id: "old")])

        #expect(harness.presenter.quizSectionState == .strip)
        #expect(harness.presenter.newQuizCardStatus == .ready)
        #expect(harness.presenter.quizzes.map(\.id) == ["new", "old"])
        #expect(harness.presenter.quizUnavailableReason == nil)
    }

    @Test("A deck with no quizzes yet shows the strip with only the + card")
    func noQuizzesYet() {
        let harness = makeHarness()

        #expect(harness.presenter.quizSectionState == .strip)
        #expect(harness.presenter.quizzes.isEmpty)
        #expect(harness.presenter.newQuizCardStatus == .ready)
    }

    @Test("When Apple Intelligence is unavailable, saved quizzes still show and the + card is greyed out")
    func aiUnavailable() {
        let harness = makeHarness(quizzes: [savedQuiz(id: "quiz1")], availability: .unavailable(.appleIntelligenceNotEnabled))

        #expect(harness.presenter.quizSectionState == .strip)
        #expect(harness.presenter.quizzes.map(\.id) == ["quiz1"])
        #expect(harness.presenter.newQuizCardStatus == .unavailable)
        #expect(harness.presenter.quizUnavailableReason == .appleIntelligenceNotEnabled)

        harness.presenter.onNewQuizCardPressed()

        #expect(harness.presenter.showNewQuizSheet == false)
        #expect(harness.interactor.prewarmCount == 0)
    }

    @Test("Saved quizzes still play when Apple Intelligence is unavailable")
    func unavailableQuizStillPlays() {
        let quiz = savedQuiz(id: "quiz1")
        let harness = makeHarness(quizzes: [quiz], availability: .unavailable(.deviceNotEligible))

        harness.presenter.onQuizPressed(quiz: quiz)

        #expect(harness.router.playedQuizzes.map(\.quiz.id) == ["quiz1"])
    }

    @Test("Source text under 1,500 characters shows no strip", arguments: [1, 1_000, 1_499])
    func shortSource(length: Int) {
        let harness = makeHarness(sourceLength: length)

        #expect(harness.presenter.quizSectionState == .needsMoreSource)
    }

    @Test("Exactly 1,500 characters of source text is enough for a quiz")
    func minimumSourceIsEnough() {
        let harness = makeHarness(sourceLength: 1_500)

        #expect(harness.presenter.quizSectionState == .strip)
    }

    @Test("A hand-made deck (empty or blank source) gets the ADR 0001 explanation", arguments: ["", "   \n  "])
    func handMade(sourceText: String) {
        let harness = makeHarness(sourceText: sourceText)

        #expect(harness.presenter.quizSectionState == .handMade)
        #expect(harness.presenter.showsQuizSection)
    }

    @Test("An empty hand-made deck with no cards hides the Quizzes section")
    func emptyHandMadeDeckHidesSection() {
        let deck = DeckModel(deckId: "deck1", name: "Empty", sourceText: "")
        let interactor = MockQuizDeckInteractor(deck: deck)
        let presenter = DeckDetailPresenter(interactor: interactor, router: MockQuizDeckRouter(), deck: deck)

        #expect(presenter.showsQuizSection == false)
    }
}

// MARK: - New Quiz Sheet

@Suite("DeckDetail Quizzes — New Quiz sheet")
@MainActor
struct DeckDetailNewQuizSheetTests {

    @Test(
        "The + card opens the sheet at min(10, max) and prewarms the model",
        arguments: [(1_500, 5, 5), (2_000, 6, 6), (3_000, 10, 10), (9_000, 20, 10)]
    )
    func opensWithDefaultCount(sourceLength: Int, expectedMax: Int, expectedDefault: Int) {
        let harness = makeHarness(sourceLength: sourceLength)
        harness.presenter.quizQuestionCount = 17

        harness.presenter.onNewQuizCardPressed()

        #expect(harness.presenter.showNewQuizSheet)
        #expect(harness.presenter.maxQuizQuestionCount == expectedMax)
        #expect(harness.presenter.quizQuestionCount == expectedDefault)
        #expect(harness.interactor.prewarmCount == 1)
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizNewCard_Pressed"))
    }

    @Test("The question count stays between 5 and the deck's maximum")
    func countIsClamped() {
        let harness = makeHarness(sourceLength: 2_400) // max 8

        harness.presenter.onQuizQuestionCountChanged(7)
        #expect(harness.presenter.quizQuestionCount == 7)

        harness.presenter.onQuizQuestionCountChanged(30)
        #expect(harness.presenter.quizQuestionCount == 8)

        harness.presenter.onQuizQuestionCountChanged(2)
        #expect(harness.presenter.quizQuestionCount == 5)
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizCount_Changed"))
    }

    @Test("Cancelling the sheet closes it without making a quiz")
    func cancelSheet() {
        let harness = makeHarness()
        harness.presenter.onNewQuizCardPressed()

        harness.presenter.onNewQuizSheetCancelled()

        #expect(harness.presenter.showNewQuizSheet == false)
        #expect(harness.presenter.newQuizCardStatus == .ready)
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizNewSheet_Cancelled"))
    }

    @Test("Swiping the sheet down is tracked as a cancel")
    func swipeDismissTracksCancel() {
        let harness = makeHarness()
        harness.presenter.onNewQuizCardPressed()

        // The sheet binding's setter calls this when SwiftUI dismisses the sheet.
        harness.presenter.onNewQuizSheetCancelled()

        #expect(harness.presenter.showNewQuizSheet == false)
        #expect(harness.interactor.mockLog.events.filter { $0.eventName == "DeckDetailView_QuizNewSheet_Cancelled" }.count == 1)
    }

    @Test("Closing the sheet with Make Quiz isn't tracked as a cancel")
    func makeQuizDismissIsNotACancel() async {
        let harness = makeHarness()
        harness.presenter.onNewQuizCardPressed()

        harness.presenter.onMakeQuizPressed()
        // SwiftUI may write `false` back through the binding as the sheet closes.
        harness.presenter.onNewQuizSheetCancelled()
        await harness.presenter.quizGenerationTask?.value

        #expect(!harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizNewSheet_Cancelled"))
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizMake_Success"))
    }

    @Test("The question count's lower bound comes from the interactor")
    func minimumFromInteractor() {
        let harness = makeHarness()

        #expect(harness.presenter.minQuizQuestionCount == QuizQuestionCount.minimum)
        #expect(harness.presenter.minQuizSourceLength == QuizQuestionCount.minimumSourceLength)
    }
}

// MARK: - Making a Quiz

@Suite("DeckDetail Quizzes — Making a quiz")
@MainActor
struct DeckDetailMakeQuizTests {

    @Test("Making a quiz shows the count while generating, then puts the new quiz at the front")
    func successInsertsQuizAtFront() async {
        let harness = makeHarness(quizzes: [savedQuiz(id: "older")])
        harness.interactor.holdsGeneration = true
        harness.presenter.onNewQuizCardPressed()

        harness.presenter.onMakeQuizPressed()

        #expect(harness.presenter.showNewQuizSheet == false)
        await waitUntil { harness.interactor.isWaitingAtGate }
        #expect(harness.presenter.newQuizCardStatus == .generating(generatedCount: 3, totalCount: 10))

        let task = harness.presenter.quizGenerationTask
        harness.interactor.releaseGeneration()
        await task?.value

        #expect(harness.presenter.quizzes.count == 2)
        #expect(harness.presenter.quizzes.first?.title == "Biology Quiz")
        #expect(harness.presenter.quizzes.last?.id == "older")
        #expect(harness.presenter.newQuizCardStatus == .ready)
        #expect(harness.router.simpleAlerts.isEmpty)
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizMake_Pressed"))
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizMake_Success"))
    }

    @Test("A failed run shows the quiz-worded error message and saves nothing")
    func failureShowsQuizMessage() async {
        let harness = makeHarness()
        let error = QuizGenerationError.tooFewQuestions(generated: 3)
        harness.interactor.generationResult = .failure(error)

        harness.presenter.onMakeQuizPressed()
        await harness.presenter.quizGenerationTask?.value

        #expect(harness.presenter.quizzes.isEmpty)
        #expect(harness.presenter.newQuizCardStatus == .ready)
        #expect(harness.router.simpleAlerts.count == 1)
        #expect(harness.router.simpleAlerts.first?.subtitle == error.userMessage)
        #expect(harness.router.simpleAlerts.first?.subtitle?.localizedCaseInsensitiveContains("flashcard") == false)
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizMake_Fail"))
    }

    @Test("A model failure uses QuizGenerationError's quiz wording, not the flashcard wording")
    func modelFailureMessage() async {
        let harness = makeHarness()
        let error = QuizGenerationError.generation(.restricted)
        harness.interactor.generationResult = .failure(error)

        harness.presenter.onMakeQuizPressed()
        await harness.presenter.quizGenerationTask?.value

        #expect(harness.router.simpleAlerts.first?.subtitle == error.userMessage)
        #expect(harness.router.simpleAlerts.first?.subtitle != GenerationFailure.restricted.userMessage)
    }

    @Test("A save error after generation gets its own message")
    func saveErrorMessage() async {
        let harness = makeHarness()
        harness.interactor.generationResult = .failure(AppError("disk full"))

        harness.presenter.onMakeQuizPressed()
        await harness.presenter.quizGenerationTask?.value

        #expect(harness.router.simpleAlerts.count == 1)
        #expect(harness.router.simpleAlerts.first?.subtitle?.contains("couldn't be saved") == true)
    }

    @Test("Tapping the + card while generating cancels, saves nothing and shows no alert")
    func cancelSavesNothing() async {
        let harness = makeHarness()
        harness.interactor.holdsGeneration = true
        harness.presenter.onMakeQuizPressed()
        await waitUntil { harness.interactor.isWaitingAtGate }
        let task = harness.presenter.quizGenerationTask

        harness.presenter.onNewQuizCardPressed()

        #expect(harness.presenter.newQuizCardStatus == .ready)
        #expect(harness.presenter.showNewQuizSheet == false)
        harness.interactor.releaseGeneration()
        await task?.value

        #expect(harness.presenter.quizzes.isEmpty)
        #expect(harness.interactor.storedQuizzes.isEmpty)
        #expect(harness.router.simpleAlerts.isEmpty)
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizMake_Cancelled"))
        #expect(!harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizMake_Success"))
        #expect(!harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizMake_Fail"))
    }

    @Test("A cancelled run's late progress doesn't overwrite a newer run's count")
    func staleProgressIgnored() async {
        let harness = makeHarness()
        harness.interactor.holdsGeneration = true
        harness.presenter.onMakeQuizPressed()
        await waitUntil { harness.interactor.runsWaitingAtGate == 1 }
        let firstTask = harness.presenter.quizGenerationTask

        harness.presenter.onNewQuizCardPressed() // cancel the first run
        harness.presenter.quizQuestionCount = 8
        harness.presenter.onMakeQuizPressed()
        await waitUntil { harness.interactor.runsWaitingAtGate == 2 }
        let secondTask = harness.presenter.quizGenerationTask
        #expect(harness.presenter.newQuizCardStatus == .generating(generatedCount: 3, totalCount: 8))

        // The first run reports late.
        harness.interactor.progressHandlers.first?(QuizGenerationProgress(generatedCount: 9, totalCount: 10))

        #expect(harness.presenter.newQuizCardStatus == .generating(generatedCount: 3, totalCount: 8))

        harness.interactor.releaseGeneration()
        await firstTask?.value
        await secondTask?.value

        #expect(harness.presenter.newQuizCardStatus == .ready)
        #expect(harness.presenter.quizzes.count == 1)
        #expect(harness.router.simpleAlerts.isEmpty)
    }

    @Test("A quiz saved just as the run was cancelled is deleted")
    func cancelAfterSaveDeletesQuiz() async {
        let harness = makeHarness()
        harness.interactor.holdsGeneration = true
        harness.interactor.savesWhenCancelled = true
        harness.presenter.onMakeQuizPressed()
        await waitUntil { harness.interactor.isWaitingAtGate }
        let task = harness.presenter.quizGenerationTask

        harness.presenter.onNewQuizCardPressed()
        harness.interactor.releaseGeneration()
        await task?.value

        #expect(harness.interactor.deletedQuizIds.count == 1)
        #expect(harness.interactor.storedQuizzes.isEmpty)
        #expect(!harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizCancelCleanup_Fail"))
    }

    @Test("A failed clean-up after a post-save cancel is tracked as severe")
    func cancelAfterSaveCleanupFailure() async {
        let harness = makeHarness()
        harness.interactor.holdsGeneration = true
        harness.interactor.savesWhenCancelled = true
        harness.interactor.deleteError = AppError("write failed")
        harness.presenter.onMakeQuizPressed()
        await waitUntil { harness.interactor.isWaitingAtGate }
        let task = harness.presenter.quizGenerationTask

        harness.presenter.onNewQuizCardPressed()
        harness.interactor.releaseGeneration()
        await task?.value

        let event = harness.interactor.mockLog.events.first { $0.eventName == "DeckDetailView_QuizCancelCleanup_Fail" }
        #expect(event?.type == .severe)
        #expect(harness.router.simpleAlerts.isEmpty)
    }

    @Test("Make Quiz starts nothing if Apple Intelligence became unavailable while the sheet was open")
    func makeQuizNeedsAI() {
        let harness = makeHarness()
        harness.presenter.onNewQuizCardPressed()
        harness.interactor.availability = .unavailable(.appleIntelligenceNotEnabled)

        harness.presenter.onMakeQuizPressed()

        #expect(harness.presenter.quizGenerationTask == nil)
        #expect(harness.presenter.showNewQuizSheet == false)
        #expect(harness.presenter.newQuizCardStatus == .unavailable)
        #expect(harness.interactor.storedQuizzes.isEmpty)
    }

    @Test("Make Quiz does nothing when the deck's source text is too short")
    func makeQuizNeedsSource() {
        let harness = makeHarness(sourceLength: 200)

        harness.presenter.onMakeQuizPressed()

        #expect(harness.presenter.quizGenerationTask == nil)
        #expect(harness.presenter.newQuizCardStatus == .ready)
    }
}

// MARK: - Opening and Deleting

@Suite("DeckDetail Quizzes — Opening and deleting")
@MainActor
struct DeckDetailQuizOpenDeleteTests {

    @Test("Tapping a quiz card opens it in the deck colour")
    func tapOpensQuiz() {
        let quiz = savedQuiz(id: "quiz1")
        let harness = makeHarness(quizzes: [quiz])

        harness.presenter.onQuizPressed(quiz: quiz)

        #expect(harness.router.playedQuizzes.count == 1)
        #expect(harness.router.playedQuizzes.first?.quiz.id == "quiz1")
        #expect(harness.router.playedQuizzes.first?.deckColor == .green)
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_Quiz_Pressed"))
    }

    @Test("The strip picks up a new best score without reloading")
    func stripReflectsLatestBestScore() {
        let quiz = savedQuiz(id: "quiz1")
        let harness = makeHarness(quizzes: [quiz])
        #expect(harness.presenter.quizzes.first?.bestScore == nil)

        // An attempt is recorded while the take-a-quiz screen is open.
        harness.interactor.replaceQuiz(quiz.appendingAttempt(QuizAttemptModel(score: 4, total: 5)))

        #expect(harness.presenter.quizzes.first?.bestScore == 4)
    }

    @Test("Delete asks for confirmation first, then deletes")
    func deleteAfterConfirmation() {
        let quiz = savedQuiz(id: "quiz1", title: "Cells")
        let harness = makeHarness(quizzes: [quiz])

        harness.presenter.onDeleteQuizPressed(quiz: quiz)

        #expect(harness.router.deleteAlertTitles == ["Cells"])
        #expect(harness.interactor.deletedQuizIds.isEmpty)

        harness.router.onDeletePressed?()

        #expect(harness.interactor.deletedQuizIds == ["quiz1"])
        #expect(harness.presenter.quizzes.isEmpty)
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizDelete_Pressed"))
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizDelete_Confirmed"))
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizDelete_Success"))
    }

    @Test("A failed delete keeps the quiz and shows an alert")
    func deleteFailure() {
        let quiz = savedQuiz(id: "quiz1")
        let harness = makeHarness(quizzes: [quiz])
        harness.interactor.deleteError = AppError("write failed")

        harness.presenter.onDeleteQuizConfirmed(quiz: quiz)

        #expect(harness.presenter.quizzes.count == 1)
        #expect(harness.router.simpleAlerts.count == 1)
        #expect(harness.interactor.mockLog.hasEvent(named: "DeckDetailView_QuizDelete_Fail"))
    }
}

// MARK: - Analytics

@Suite("DeckDetail Quizzes — Analytics")
@MainActor
struct DeckDetailQuizAnalyticsTests {

    @Test("Every new presenter action tracks an event")
    func everyActionTracks() async {
        let quiz = savedQuiz(id: "quiz1")
        let harness = makeHarness(quizzes: [quiz])
        let presenter = harness.presenter

        presenter.onQuizPressed(quiz: quiz)
        presenter.onDeleteQuizPressed(quiz: quiz)
        presenter.onDeleteQuizConfirmed(quiz: quiz)
        presenter.onNewQuizCardPressed()
        presenter.onQuizQuestionCountChanged(6)
        presenter.onNewQuizSheetCancelled()
        presenter.onMakeQuizPressed()
        await presenter.quizGenerationTask?.value

        let expected = [
            "DeckDetailView_Quiz_Pressed",
            "DeckDetailView_QuizDelete_Pressed",
            "DeckDetailView_QuizDelete_Confirmed",
            "DeckDetailView_QuizNewCard_Pressed",
            "DeckDetailView_QuizCount_Changed",
            "DeckDetailView_QuizNewSheet_Cancelled",
            "DeckDetailView_QuizMake_Pressed"
        ]
        for name in expected {
            #expect(harness.interactor.mockLog.hasEvent(named: name), "Missing \(name)")
        }
    }

    @Test("Failure events are severe")
    func failuresAreSevere() async {
        let harness = makeHarness()
        harness.interactor.generationResult = .failure(QuizGenerationError.generation(.other("boom")))

        harness.presenter.onMakeQuizPressed()
        await harness.presenter.quizGenerationTask?.value

        let failEvent = harness.interactor.mockLog.events.first { $0.eventName == "DeckDetailView_QuizMake_Fail" }
        #expect(failEvent?.type == .severe)
        #expect(failEvent?.parameters?["failure"] as? String == "other")
    }
}
