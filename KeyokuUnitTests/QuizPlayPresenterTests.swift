//
//  QuizPlayPresenterTests.swift
//  KeyokuUnitTests
//

// Tests for the take-a-quiz presenter: shuffling, scoring, leaving early,
// finishing (one attempt + one streak event, no XP) and analytics coverage.
// Uses in-memory mocks — no Firebase or simulator needed.

import Testing
@testable import Keyoku
import SwiftfulGamification
import Foundation

// MARK: - Mocks

@MainActor
private final class MockQuizPlayInteractor: QuizPlayInteractor {

    let mockLog = MockLogService()
    private(set) var recordedAttempts: [QuizAttemptModel] = []
    private(set) var streakEventCount: Int = 0
    private(set) var rescheduleCount: Int = 0
    private(set) var playedHaptics: [HapticOption] = []
    var streakBefore: Int = 2
    var streakAfter: Int = 3
    var recordAttemptError: Error?

    private let quiz: QuizModel

    init(quiz: QuizModel) {
        self.quiz = quiz
    }

    var currentStreakData: CurrentStreakData {
        CurrentStreakData(streakKey: "test", currentStreak: streakEventCount > 0 ? streakAfter : streakBefore)
    }

    func addStreakEvent(metadata: [String: GamificationDictionaryValue]) async throws -> StreakEvent {
        streakEventCount += 1
        return StreakEvent.mock(metadata: metadata)
    }

    func recordQuizAttempt(quizId: String, score: Int, total: Int) throws -> QuizModel {
        if let recordAttemptError { throw recordAttemptError }
        recordedAttempts.append(QuizAttemptModel(score: score, total: total))
        return quiz.appendingAttempt(QuizAttemptModel(score: score, total: total))
    }

    func schedulePushNotificationsForTheNextWeek(dueCount: Int, stillLearningCount: Int) {
        rescheduleCount += 1
    }

    // GlobalInteractor
    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType) {
        mockLog.trackEvent(event: AnyLoggableEvent(eventName: eventName, parameters: parameters, type: type))
    }
    func trackEvent(event: AnyLoggableEvent) { mockLog.trackEvent(event: event) }
    func trackEvent(event: LoggableEvent) { mockLog.trackEvent(event: event) }
    func trackScreenEvent(event: LoggableEvent) { mockLog.trackScreenView(event: event) }
    func playHaptic(option: HapticOption) { playedHaptics.append(option) }
}

@MainActor
private final class MockQuizPlayRouter: QuizPlayRouter {
    var router: AnyRouter { fatalError("router not accessed in these tests") }
    private(set) var leaveAlertCount: Int = 0
    private(set) var dismissCount: Int = 0
    private(set) var onLeavePressed: (@MainActor @Sendable () -> Void)?
    private(set) var onStayPressed: (@MainActor @Sendable () -> Void)?

    func showLeaveQuizAlert(
        onLeavePressed: @escaping @MainActor @Sendable () -> Void,
        onStayPressed: @escaping @MainActor @Sendable () -> Void
    ) {
        leaveAlertCount += 1
        self.onLeavePressed = onLeavePressed
        self.onStayPressed = onStayPressed
    }

    func dismissScreen() {
        dismissCount += 1
    }
}

// MARK: - Helpers

@MainActor
private struct Harness {
    let presenter: QuizPlayPresenter
    let interactor: MockQuizPlayInteractor
    let router: MockQuizPlayRouter
}

@MainActor
private func makeHarness(
    quiz: QuizModel = QuizModel(deckId: "deck1", title: "Test Quiz", questions: QuizQuestionModel.mocks)
) -> Harness {
    let interactor = MockQuizPlayInteractor(quiz: quiz)
    let router = MockQuizPlayRouter()
    let presenter = QuizPlayPresenter(interactor: interactor, router: router, quiz: quiz, deckColor: .blue)
    return Harness(presenter: presenter, interactor: interactor, router: router)
}

@MainActor
private func answerCurrent(_ presenter: QuizPlayPresenter, correctly: Bool) {
    guard let question = presenter.currentQuestion else { return }
    let index = correctly
        ? question.correctAnswerIndex
        : question.answers.indices.first { $0 != question.correctAnswerIndex } ?? 0
    presenter.onAnswerSelected(answerIndex: index)
}

/// Answers every question; the first `correctCount` are answered correctly.
@MainActor
private func playThrough(_ presenter: QuizPlayPresenter, correctCount: Int) {
    for questionIndex in 0..<presenter.total {
        answerCurrent(presenter, correctly: questionIndex < correctCount)
        presenter.onContinuePressed()
    }
}

/// The attempt's question order plus each question's answer order.
@MainActor
private func attemptOrder(_ presenter: QuizPlayPresenter) -> [[String]] {
    presenter.questions.map { [$0.id] + $0.answers }
}

// MARK: - Shuffling

@Suite("QuizPlayPresenter — Shuffling")
@MainActor
struct QuizPlayShuffleTests {

    @Test("An attempt holds every question once and every answer once")
    func attemptIsPermutation() throws {
        let harness = makeHarness()
        let presenter = harness.presenter

        #expect(Set(presenter.questions.map(\.id)) == Set(QuizQuestionModel.mocks.map(\.id)))
        #expect(presenter.questions.count == QuizQuestionModel.mocks.count)

        for played in presenter.questions {
            let model = try #require(QuizQuestionModel.mocks.first { $0.id == played.id })
            #expect(played.answers.sorted() == ([model.correctAnswer] + model.wrongAnswers).sorted())
            #expect(played.correctAnswer == model.correctAnswer)
        }
    }

    @Test("Retake reshuffles question and answer order")
    func retakeReshuffles() {
        let harness = makeHarness()
        let presenter = harness.presenter
        let firstOrder = attemptOrder(presenter)

        // 5 questions × 4 answers: the chance of 20 identical shuffles in a row is negligible.
        var sawDifferentOrder = false
        for _ in 0..<20 {
            playThrough(presenter, correctCount: 0)
            presenter.onRetakePressed()
            if attemptOrder(presenter) != firstOrder {
                sawDifferentOrder = true
                break
            }
        }

        #expect(sawDifferentOrder)
        #expect(Set(presenter.questions.map(\.id)) == Set(QuizQuestionModel.mocks.map(\.id)))
    }

    @Test("Retake resets the attempt")
    func retakeResets() {
        let harness = makeHarness()
        let presenter = harness.presenter
        playThrough(presenter, correctCount: 3)

        presenter.onRetakePressed()

        #expect(!presenter.isFinished)
        #expect(presenter.currentIndex == 0)
        #expect(presenter.answeredCount == 0)
        #expect(presenter.score == 0)
        #expect(presenter.progressSegments.first == .current)
    }
}

// MARK: - Answering & Scoring

@Suite("QuizPlayPresenter — Answering and scoring")
@MainActor
struct QuizPlayScoringTests {

    @Test("Score counts correct answers")
    func scoreCountsCorrect() {
        let harness = makeHarness()
        let presenter = harness.presenter

        playThrough(presenter, correctCount: 3)

        #expect(presenter.isFinished)
        #expect(presenter.score == 3)
        #expect(presenter.total == 5)
        #expect(!presenter.isPerfect)
    }

    @Test("All correct is a perfect score")
    func perfectScore() {
        let harness = makeHarness()
        let presenter = harness.presenter

        playThrough(presenter, correctCount: 5)

        #expect(presenter.score == 5)
        #expect(presenter.isPerfect)
    }

    @Test("One tap locks the answer")
    func firstTapLocks() throws {
        let harness = makeHarness()
        let presenter = harness.presenter
        let question = try #require(presenter.currentQuestion)
        let wrongIndex = try #require(question.answers.indices.first { $0 != question.correctAnswerIndex })

        presenter.onAnswerSelected(answerIndex: wrongIndex)
        presenter.onAnswerSelected(answerIndex: question.correctAnswerIndex)

        #expect(presenter.selectedAnswerIndices[0] == wrongIndex)
        #expect(presenter.answerState(at: wrongIndex) == .incorrect)
        #expect(presenter.answerState(at: question.correctAnswerIndex) == .correct)
        #expect(presenter.progressSegments[0] == .incorrect)
        #expect(presenter.feedback?.isCorrect == false)
        #expect(presenter.feedback?.correctAnswer == question.correctAnswer)
    }

    @Test("Right and wrong answers play success and error haptics")
    func answerHaptics() {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor

        answerCurrent(presenter, correctly: true)
        presenter.onContinuePressed()
        answerCurrent(presenter, correctly: false)

        guard interactor.playedHaptics.count == 2 else {
            Issue.record("Expected 2 haptics, got \(interactor.playedHaptics.count)")
            return
        }
        if case .success = interactor.playedHaptics[0] {} else { Issue.record("First haptic should be .success") }
        if case .error = interactor.playedHaptics[1] {} else { Issue.record("Second haptic should be .error") }
    }

    @Test("Continue does nothing before the question is answered")
    func continueRequiresAnswer() {
        let harness = makeHarness()
        let presenter = harness.presenter

        presenter.onContinuePressed()

        #expect(presenter.currentIndex == 0)
        #expect(presenter.feedback == nil)
    }

    @Test("The last question's feedback says See Results")
    func lastQuestionButton() {
        let harness = makeHarness()
        let presenter = harness.presenter
        for _ in 0..<(presenter.total - 1) {
            answerCurrent(presenter, correctly: true)
            #expect(presenter.feedback?.buttonTitle == "Continue")
            presenter.onContinuePressed()
        }

        answerCurrent(presenter, correctly: true)

        #expect(presenter.feedback?.buttonTitle == "See Results")
    }
}

// MARK: - Leaving

@Suite("QuizPlayPresenter — Leaving early")
@MainActor
struct QuizPlayLeavingTests {

    @Test("Closing mid-quiz asks first; leaving records nothing")
    func leavingRecordsNothing() async {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor
        let router = harness.router
        answerCurrent(presenter, correctly: true)
        presenter.onContinuePressed()
        answerCurrent(presenter, correctly: false)

        presenter.onClosePressed()
        #expect(router.leaveAlertCount == 1)
        #expect(router.dismissCount == 0)

        router.onLeavePressed?()
        await presenter.recordStreakTask?.value

        #expect(router.dismissCount == 1)
        #expect(interactor.recordedAttempts.isEmpty)
        #expect(interactor.streakEventCount == 0)
        #expect(interactor.rescheduleCount == 0)
        #expect(interactor.mockLog.hasEvent(named: "QuizPlayView_Leave_Confirmed"))
        #expect(!interactor.mockLog.hasEvent(named: "QuizPlayView_QuizCompleted"))
    }

    @Test("Keep Going stays on the quiz")
    func stayKeepsQuiz() {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor
        let router = harness.router
        answerCurrent(presenter, correctly: true)

        presenter.onClosePressed()
        router.onStayPressed?()

        #expect(router.dismissCount == 0)
        #expect(presenter.answeredCount == 1)
        #expect(interactor.mockLog.hasEvent(named: "QuizPlayView_Leave_Cancelled"))
    }

    @Test("Closing before any answer leaves without asking")
    func closeBeforeAnswering() {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor
        let router = harness.router

        presenter.onClosePressed()

        #expect(router.leaveAlertCount == 0)
        #expect(router.dismissCount == 1)
        #expect(interactor.recordedAttempts.isEmpty)
    }
}

// MARK: - Finishing

@Suite("QuizPlayPresenter — Finishing")
@MainActor
struct QuizPlayFinishTests {

    @Test("Finishing records exactly one attempt and one streak event")
    func finishRecordsOnce() async throws {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor

        playThrough(presenter, correctCount: 4)
        await presenter.recordStreakTask?.value

        #expect(interactor.recordedAttempts.count == 1)
        let attempt = try #require(interactor.recordedAttempts.first)
        #expect(attempt.score == 4)
        #expect(attempt.total == 5)
        #expect(interactor.streakEventCount == 1)
        #expect(interactor.rescheduleCount == 1)
        #expect(interactor.mockLog.hasEvent(named: "QuizPlayView_QuizCompleted"))
        #expect(interactor.mockLog.hasEvent(named: "QuizPlayView_Streak_Recorded"))
    }

    @Test("Finishing plays the lesson-complete haptic")
    func finishHaptic() {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor

        playThrough(presenter, correctCount: 5)

        guard let last = interactor.playedHaptics.last else {
            Issue.record("No haptic played")
            return
        }
        if case .lessonComplete = last {} else { Issue.record("Last haptic should be .lessonComplete") }
    }

    @Test("A streak increase is celebrated")
    func streakIncreaseCelebrated() async {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor
        interactor.streakBefore = 2
        interactor.streakAfter = 3

        playThrough(presenter, correctCount: 1)
        await presenter.recordStreakTask?.value

        #expect(presenter.newStreakCount == 3)
        #expect(presenter.currentStreak == 3)
    }

    @Test("No celebration when the streak didn't increase")
    func streakUnchangedNotCelebrated() async {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor
        interactor.streakBefore = 3
        interactor.streakAfter = 3

        playThrough(presenter, correctCount: 1)
        await presenter.recordStreakTask?.value

        #expect(presenter.newStreakCount == 0)
        #expect(presenter.currentStreak == 3)
    }

    @Test("Best score includes this attempt")
    func bestScoreIncludesAttempt() async {
        let quiz = QuizModel(
            deckId: "deck1",
            title: "Test",
            questions: QuizQuestionModel.mocks,
            attempts: [QuizAttemptModel(score: 2, total: 5)]
        )
        let harness = makeHarness(quiz: quiz)
        let presenter = harness.presenter

        playThrough(presenter, correctCount: 4)

        #expect(presenter.bestScore == 4)
    }

    @Test("A failed attempt save still shows results and is logged")
    func recordAttemptFailure() async {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor
        interactor.recordAttemptError = AppError("Disk full")

        playThrough(presenter, correctCount: 2)
        await presenter.recordStreakTask?.value

        #expect(presenter.isFinished)
        #expect(presenter.bestScore >= 2)
        #expect(interactor.mockLog.hasEvent(named: "QuizPlayView_RecordAttempt_Fail"))
    }

    @Test("Retake then finish records a second attempt")
    func retakeRecordsAgain() async {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor

        playThrough(presenter, correctCount: 1)
        await presenter.recordStreakTask?.value
        presenter.onRetakePressed()
        playThrough(presenter, correctCount: 5)
        await presenter.recordStreakTask?.value

        #expect(interactor.recordedAttempts.map(\.score) == [1, 5])
        #expect(interactor.streakEventCount == 2)
    }
}

// MARK: - Analytics

@Suite("QuizPlayPresenter — Analytics")
@MainActor
struct QuizPlayAnalyticsTests {

    @Test("Every presenter method tracks an event")
    func everyMethodTracks() async {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor
        let router = harness.router
        let delegate = QuizPlayDelegate(quiz: presenter.quiz, deckColor: .blue)
        let log = interactor.mockLog

        func tracks(_ name: String, _ action: () -> Void) {
            let before = log.events.count
            action()
            #expect(log.events.count > before, "\(name) tracked no event")
        }

        tracks("onViewAppear") { presenter.onViewAppear(delegate: delegate) }
        tracks("onAnswerSelected") { answerCurrent(presenter, correctly: true) }
        tracks("onContinuePressed") { presenter.onContinuePressed() }
        tracks("onClosePressed") { answerCurrent(presenter, correctly: true); presenter.onClosePressed() }
        tracks("onLeaveCancelled") { presenter.onLeaveCancelled() }
        tracks("onLeaveConfirmed") { presenter.onLeaveConfirmed() }
        tracks("onViewDisappear") { presenter.onViewDisappear(delegate: delegate) }
        tracks("onRetakePressed") { presenter.onRetakePressed() }
        tracks("onDonePressed") { presenter.onDonePressed() }

        #expect(router.dismissCount == 2)
    }

    @Test("QuizStarted fires once on first appear and again on retake; QuizCompleted on finish")
    func startedAndCompleted() {
        let harness = makeHarness()
        let presenter = harness.presenter
        let interactor = harness.interactor
        let delegate = QuizPlayDelegate(quiz: presenter.quiz, deckColor: .blue)
        let log = interactor.mockLog

        presenter.onViewAppear(delegate: delegate)
        presenter.onViewAppear(delegate: delegate)
        #expect(log.events.filter { $0.eventName == "QuizPlayView_QuizStarted" }.count == 1)

        playThrough(presenter, correctCount: 2)
        let completed = log.events.filter { $0.eventName == "QuizPlayView_QuizCompleted" }
        #expect(completed.count == 1)
        #expect(completed.first?.parameters?["score"] as? Int == 2)

        presenter.onRetakePressed()
        #expect(log.events.filter { $0.eventName == "QuizPlayView_QuizStarted" }.count == 2)
    }
}
