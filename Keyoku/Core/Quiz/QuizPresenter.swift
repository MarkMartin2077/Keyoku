//
//  QuizPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@Observable
@MainActor
class QuizPresenter {

    private let interactor: QuizInteractor
    private let router: QuizRouter

    let quizName: String
    let quizColor: DeckColor
    private(set) var questions: [QuizQuestionModel]
    private(set) var currentIndex: Int = 0
    private(set) var selectedAnswerIndex: Int?
    private(set) var isAnswerRevealed: Bool = false
    private(set) var isQuizComplete: Bool = false
    private(set) var correctAnswers: Int = 0

    var currentQuestion: QuizQuestionModel? {
        guard !questions.isEmpty, currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(questions.count)
    }

    var scorePercentage: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(correctAnswers) / Double(questions.count) * 100
    }

    init(interactor: QuizInteractor, router: QuizRouter, quiz: QuizModel) {
        self.interactor = interactor
        self.router = router
        self.quizName = quiz.name
        self.quizColor = quiz.color
        self.questions = quiz.questions
    }

    func onViewAppear(delegate: QuizDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        interactor.playHaptic(option: .quizStart())
    }

    func onViewDisappear(delegate: QuizDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onOptionSelected(index: Int) {
        guard !isAnswerRevealed else { return }

        selectedAnswerIndex = index
        isAnswerRevealed = true

        let isCorrect = index == currentQuestion?.correctAnswerIndex
        if isCorrect {
            correctAnswers += 1
            interactor.playHaptic(option: .correctAnswer())
        } else {
            interactor.playHaptic(option: .incorrectGentle())
        }

        interactor.trackEvent(event: Event.onOptionSelected(
            questionIndex: currentIndex,
            selectedIndex: index,
            isCorrect: isCorrect
        ))
    }

    func onNextPressed() {
        guard isAnswerRevealed else { return }

        if currentIndex < questions.count - 1 {
            interactor.trackEvent(event: Event.onNextPressed(fromIndex: currentIndex))

            withAnimation(.easeInOut(duration: 0.2)) {
                currentIndex += 1
                selectedAnswerIndex = nil
                isAnswerRevealed = false
            }
        } else {
            interactor.trackEvent(event: Event.onQuizComplete(
                score: correctAnswers,
                total: questions.count
            ))

            if correctAnswers == questions.count {
                interactor.playHaptic(option: .perfectScore())
            } else if scorePercentage >= 80 {
                interactor.playHaptic(option: .lessonComplete())
            } else {
                interactor.playHaptic(option: .success)
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                isQuizComplete = true
            }
        }
    }

    func onRetakePressed() {
        interactor.trackEvent(event: Event.onRetakePressed(
            previousScore: correctAnswers,
            total: questions.count
        ))

        withAnimation(.easeInOut(duration: 0.3)) {
            questions.shuffle()
            currentIndex = 0
            selectedAnswerIndex = nil
            isAnswerRevealed = false
            isQuizComplete = false
            correctAnswers = 0
        }
    }

    func onDonePressed() {
        interactor.trackEvent(event: Event.onDonePressed(
            score: correctAnswers,
            total: questions.count
        ))
        router.dismissScreen()
    }
}

extension QuizPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: QuizDelegate)
        case onDisappear(delegate: QuizDelegate)
        case onOptionSelected(questionIndex: Int, selectedIndex: Int, isCorrect: Bool)
        case onNextPressed(fromIndex: Int)
        case onQuizComplete(score: Int, total: Int)
        case onRetakePressed(previousScore: Int, total: Int)
        case onDonePressed(score: Int, total: Int)

        var eventName: String {
            switch self {
            case .onAppear:             return "QuizView_Appear"
            case .onDisappear:          return "QuizView_Disappear"
            case .onOptionSelected:     return "QuizView_Option_Selected"
            case .onNextPressed:        return "QuizView_Next_Pressed"
            case .onQuizComplete:       return "QuizView_Complete"
            case .onRetakePressed:      return "QuizView_Retake_Pressed"
            case .onDonePressed:        return "QuizView_Done_Pressed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate):
                return delegate.eventParameters
            case .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onOptionSelected(questionIndex: let quesIndex, selectedIndex: let selectedIndex, isCorrect: let correct):
                return ["question_index": quesIndex, "selected_index": selectedIndex, "is_correct": correct]
            case .onNextPressed(fromIndex: let index):
                return ["from_index": index]
            case .onQuizComplete(score: let score, total: let total),
                 .onDonePressed(score: let score, total: let total):
                return ["score": score, "total": total, "percentage": total > 0 ? Double(score) / Double(total) * 100 : 0]
            case .onRetakePressed(previousScore: let score, total: let total):
                return ["previous_score": score, "total": total]
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
