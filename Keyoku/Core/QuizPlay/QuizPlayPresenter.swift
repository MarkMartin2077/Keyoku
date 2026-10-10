//
//  QuizPlayPresenter.swift
//  Keyoku
//

import SwiftUI

/// One question as played in a single quiz attempt, with its answers in shuffled order.
struct QuizPlayQuestion: Identifiable, Equatable {
    let id: String
    let question: String
    let answers: [String]
    let correctAnswerIndex: Int
    let explanation: String

    var correctAnswer: String {
        answers[correctAnswerIndex]
    }

    /// Shuffles the correct answer in among the wrong ones.
    init(model: QuizQuestionModel) {
        let shuffled = ([(model.correctAnswer, true)] + model.wrongAnswers.map { ($0, false) }).shuffled()
        self.id = model.id
        self.question = model.question
        self.answers = shuffled.map(\.0)
        // The correct answer is always in `shuffled`, so the fallback is unreachable.
        self.correctAnswerIndex = shuffled.firstIndex(where: \.1) ?? 0
        self.explanation = model.explanation
    }
}

/// What the feedback sheet shows after the current question is answered.
struct QuizPlayFeedback: Identifiable, Equatable {
    let id: String
    let isCorrect: Bool
    let correctAnswer: String
    let explanation: String
    let isLastQuestion: Bool

    var buttonTitle: String {
        isLastQuestion ? "See Results" : "Continue"
    }
}

/// Drives one quiz: shuffles questions and answers for every attempt, locks each answer on the
/// first tap, scores the attempt, and on finish records the attempt plus a streak event
/// (no XP, and no change to card scheduling — ADR 0002). Leaving early records nothing.
@Observable
@MainActor
class QuizPlayPresenter {

    private let interactor: QuizPlayInteractor
    private let router: QuizPlayRouter

    private(set) var quiz: QuizModel
    let deckColor: DeckColor

    private(set) var questions: [QuizPlayQuestion] = []
    private(set) var currentIndex: Int = 0
    /// The answer index picked for each question in `questions`, or `nil` while unanswered.
    private(set) var selectedAnswerIndices: [Int?] = []
    private(set) var isFinished: Bool = false

    /// Streak after this attempt's streak event, shown on the end screen.
    private(set) var currentStreak: Int = 0
    /// Set when this attempt's streak event increased the streak, to celebrate it.
    private(set) var newStreakCount: Int = 0
    /// The in-flight streak recording, kept so tests can await it.
    private(set) var recordStreakTask: Task<Void, Never>?

    private var hasTrackedFirstStart: Bool = false

    init(interactor: QuizPlayInteractor, router: QuizPlayRouter, quiz: QuizModel, deckColor: DeckColor) {
        self.interactor = interactor
        self.router = router
        self.quiz = quiz
        self.deckColor = deckColor
        resetAttempt()
    }

    // MARK: - Derived State

    var title: String {
        quiz.title
    }

    var total: Int {
        questions.count
    }

    var currentQuestion: QuizPlayQuestion? {
        guard !isFinished, questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var answeredCount: Int {
        selectedAnswerIndices.compactMap { $0 }.count
    }

    var score: Int {
        zip(questions, selectedAnswerIndices).filter { question, selected in
            selected == question.correctAnswerIndex
        }.count
    }

    var isPerfect: Bool {
        total > 0 && score == total
    }

    /// Best score across every recorded attempt, including this one once finished.
    var bestScore: Int {
        max(quiz.bestScore ?? 0, isFinished ? score : 0)
    }

    var progressSegments: [QuizProgressSegment] {
        questions.indices.map { index in
            if let selected = selectedAnswerIndices[index] {
                return selected == questions[index].correctAnswerIndex ? .correct : .incorrect
            }
            return index == currentIndex && !isFinished ? .current : .upcoming
        }
    }

    func answerState(at answerIndex: Int) -> QuizAnswerState {
        guard let question = currentQuestion, let selected = selectedAnswerIndices[currentIndex] else {
            return .idle
        }
        if answerIndex == question.correctAnswerIndex { return .correct }
        if answerIndex == selected { return .incorrect }
        return .dimmed
    }

    /// Non-nil while the current question is answered and waiting for Continue.
    var feedback: QuizPlayFeedback? {
        guard let question = currentQuestion, let selected = selectedAnswerIndices[currentIndex] else {
            return nil
        }
        return QuizPlayFeedback(
            id: question.id,
            isCorrect: selected == question.correctAnswerIndex,
            correctAnswer: question.correctAnswer,
            explanation: question.explanation,
            isLastQuestion: currentIndex == questions.count - 1
        )
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: QuizPlayDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))

        if !hasTrackedFirstStart {
            hasTrackedFirstStart = true
            interactor.trackEvent(event: Event.quizStarted(quiz: quiz, isRetake: false))
        }
    }

    func onViewDisappear(delegate: QuizPlayDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate, answeredCount: answeredCount, isFinished: isFinished))
    }

    // MARK: - Answering

    func onAnswerSelected(answerIndex: Int) {
        guard let question = currentQuestion,
              selectedAnswerIndices[currentIndex] == nil,
              question.answers.indices.contains(answerIndex) else { return }

        selectedAnswerIndices[currentIndex] = answerIndex
        let isCorrect = answerIndex == question.correctAnswerIndex
        interactor.playHaptic(option: isCorrect ? .success : .error)
        interactor.trackEvent(event: Event.onAnswerSelected(
            questionId: question.id,
            questionIndex: currentIndex,
            isCorrect: isCorrect
        ))
    }

    func onContinuePressed() {
        guard currentQuestion != nil, selectedAnswerIndices[currentIndex] != nil else { return }

        let isLastQuestion = currentIndex == questions.count - 1
        interactor.trackEvent(event: Event.onContinuePressed(questionIndex: currentIndex, isLastQuestion: isLastQuestion))

        if isLastQuestion {
            finishAttempt()
        } else {
            currentIndex += 1
        }
    }

    // MARK: - Leaving

    func onClosePressed() {
        interactor.trackEvent(event: Event.onClosePressed(answeredCount: answeredCount, isFinished: isFinished))

        guard !isFinished, answeredCount > 0 else {
            router.dismissScreen()
            return
        }

        router.showLeaveQuizAlert(
            onLeavePressed: { [weak self] in
                self?.onLeaveConfirmed()
            },
            onStayPressed: { [weak self] in
                self?.onLeaveCancelled()
            }
        )
    }

    /// Leaves mid-quiz. Records nothing: no attempt and no streak event.
    func onLeaveConfirmed() {
        interactor.trackEvent(event: Event.onLeaveConfirmed(answeredCount: answeredCount, total: total))
        router.dismissScreen()
    }

    func onLeaveCancelled() {
        interactor.trackEvent(event: Event.onLeaveCancelled(answeredCount: answeredCount))
    }

    // MARK: - End Screen

    func onRetakePressed() {
        interactor.trackEvent(event: Event.onRetakePressed(previousScore: score, total: total))
        interactor.playHaptic(option: .medium)

        withAnimation(.easeInOut(duration: 0.3)) {
            resetAttempt()
        }
        interactor.trackEvent(event: Event.quizStarted(quiz: quiz, isRetake: true))
    }

    func onDonePressed() {
        interactor.trackEvent(event: Event.onDonePressed(score: score, total: total))
        router.dismissScreen()
    }

    // MARK: - Private

    /// Starts a fresh attempt: reshuffles question order and each question's answer order.
    private func resetAttempt() {
        questions = quiz.questions.shuffled().map(QuizPlayQuestion.init(model:))
        selectedAnswerIndices = Array(repeating: nil, count: questions.count)
        currentIndex = 0
        isFinished = false
        newStreakCount = 0
    }

    private func finishAttempt() {
        isFinished = true
        interactor.playHaptic(option: .lessonComplete())
        interactor.trackEvent(event: Event.quizCompleted(quizId: quiz.id, score: score, total: total))

        recordAttempt()
        recordStreakEvent()
    }

    private func recordAttempt() {
        do {
            quiz = try interactor.recordQuizAttempt(quizId: quiz.id, score: score, total: total)
        } catch {
            interactor.trackEvent(event: Event.onRecordAttemptFail(error: error))
        }
    }

    private func recordStreakEvent() {
        let previousStreak = interactor.currentStreakData.currentStreak ?? 0
        currentStreak = previousStreak
        let metadata: [String: GamificationDictionaryValue] = [
            "activity": .string("quiz"),
            "quiz_id": .string(quiz.id),
            "question_count": .int(total)
        ]

        recordStreakTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await interactor.addStreakEvent(metadata: metadata)
                interactor.trackEvent(event: Event.onStreakEventRecorded(quizId: quiz.id))

                let updatedStreak = interactor.currentStreakData.currentStreak ?? 0
                currentStreak = updatedStreak
                if updatedStreak > previousStreak {
                    newStreakCount = updatedStreak
                }

                // Reschedule the next week of reminders now that the learner studied today.
                interactor.schedulePushNotificationsForTheNextWeek(dueCount: 0, stillLearningCount: 0)
            } catch {
                interactor.trackEvent(event: Event.onStreakEventFailed(error: error))
            }
        }
    }
}

extension QuizPlayPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: QuizPlayDelegate)
        case onDisappear(delegate: QuizPlayDelegate, answeredCount: Int, isFinished: Bool)
        case quizStarted(quiz: QuizModel, isRetake: Bool)
        case quizCompleted(quizId: String, score: Int, total: Int)
        case onAnswerSelected(questionId: String, questionIndex: Int, isCorrect: Bool)
        case onContinuePressed(questionIndex: Int, isLastQuestion: Bool)
        case onClosePressed(answeredCount: Int, isFinished: Bool)
        case onLeaveConfirmed(answeredCount: Int, total: Int)
        case onLeaveCancelled(answeredCount: Int)
        case onRetakePressed(previousScore: Int, total: Int)
        case onDonePressed(score: Int, total: Int)
        case onRecordAttemptFail(error: Error)
        case onStreakEventRecorded(quizId: String)
        case onStreakEventFailed(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                 return "QuizPlayView_Appear"
            case .onDisappear:              return "QuizPlayView_Disappear"
            case .quizStarted:              return "QuizPlayView_QuizStarted"
            case .quizCompleted:            return "QuizPlayView_QuizCompleted"
            case .onAnswerSelected:         return "QuizPlayView_Answer_Selected"
            case .onContinuePressed:        return "QuizPlayView_Continue_Pressed"
            case .onClosePressed:           return "QuizPlayView_Close_Pressed"
            case .onLeaveConfirmed:         return "QuizPlayView_Leave_Confirmed"
            case .onLeaveCancelled:         return "QuizPlayView_Leave_Cancelled"
            case .onRetakePressed:          return "QuizPlayView_Retake_Pressed"
            case .onDonePressed:            return "QuizPlayView_Done_Pressed"
            case .onRecordAttemptFail:      return "QuizPlayView_RecordAttempt_Fail"
            case .onStreakEventRecorded:    return "QuizPlayView_Streak_Recorded"
            case .onStreakEventFailed:      return "QuizPlayView_Streak_Failed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate):
                return delegate.eventParameters
            case .onDisappear(delegate: let delegate, answeredCount: let answeredCount, isFinished: let isFinished):
                var params = delegate.eventParameters
                params["answered_count"] = answeredCount
                params["is_finished"] = isFinished
                return params
            case .quizStarted(quiz: let quiz, isRetake: let isRetake):
                var params = quiz.eventParameters
                params["is_retake"] = isRetake
                return params
            case .quizCompleted(quizId: let quizId, score: let score, total: let total):
                return ["quiz_id": quizId, "score": score, "total": total, "is_perfect": score == total]
            case .onAnswerSelected(questionId: let questionId, questionIndex: let questionIndex, isCorrect: let isCorrect):
                return ["question_id": questionId, "question_index": questionIndex, "is_correct": isCorrect]
            case .onContinuePressed(questionIndex: let questionIndex, isLastQuestion: let isLastQuestion):
                return ["question_index": questionIndex, "is_last_question": isLastQuestion]
            case .onClosePressed(answeredCount: let answeredCount, isFinished: let isFinished):
                return ["answered_count": answeredCount, "is_finished": isFinished]
            case .onLeaveConfirmed(answeredCount: let answeredCount, total: let total):
                return ["answered_count": answeredCount, "total": total]
            case .onLeaveCancelled(answeredCount: let answeredCount):
                return ["answered_count": answeredCount]
            case .onRetakePressed(previousScore: let score, total: let total), .onDonePressed(score: let score, total: let total):
                return ["score": score, "total": total]
            case .onStreakEventRecorded(quizId: let quizId):
                return ["quiz_id": quizId]
            case .onRecordAttemptFail(error: let error), .onStreakEventFailed(error: let error):
                return error.eventParameters
            }
        }

        var type: LogType {
            switch self {
            case .onRecordAttemptFail, .onStreakEventFailed:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
