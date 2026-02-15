//
//  QuizDetailPresenter.swift
//  Keyoku
//

import SwiftUI

@Observable
@MainActor
class QuizDetailPresenter {

    private let interactor: QuizDetailInteractor
    private let router: QuizDetailRouter

    let quizId: String
    let quizName: String
    let quizColor: DeckColor

    var quiz: QuizModel? {
        interactor.getQuiz(id: quizId)
    }

    var questions: [QuizQuestionModel] {
        quiz?.questions ?? []
    }

    init(interactor: QuizDetailInteractor, router: QuizDetailRouter, quiz: QuizModel) {
        self.interactor = interactor
        self.router = router
        self.quizId = quiz.quizId
        self.quizName = quiz.name
        self.quizColor = quiz.color
    }

    func onViewAppear(delegate: QuizDetailDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: QuizDetailDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onPracticePressed() {
        interactor.trackEvent(event: Event.onPracticePressed(quizId: quizId))
        guard let quiz else { return }
        router.showQuizView(quiz: quiz, startingAt: 0)
    }

    func onQuestionPressed(question: QuizQuestionModel) {
        guard let quiz else { return }
        let index = questions.firstIndex(where: { $0.id == question.id }) ?? 0
        interactor.trackEvent(event: Event.onQuestionPressed(questionId: question.questionId, index: index))
        router.showQuizView(quiz: quiz, startingAt: index)
    }

    func onDeleteQuestion(at indexSet: IndexSet) {
        for index in indexSet {
            let question = questions[index]
            interactor.trackEvent(event: Event.onDeleteQuestionPressed(questionId: question.questionId))

            do {
                try interactor.deleteQuizQuestion(questionId: question.questionId, fromQuizId: quizId)
                interactor.trackEvent(event: Event.onDeleteQuestionSuccess(questionId: question.questionId))
            } catch {
                interactor.trackEvent(event: Event.onDeleteQuestionFail(error: error))
                router.showAlert(error: error)
            }
        }
    }
}

extension QuizDetailPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: QuizDetailDelegate)
        case onDisappear(delegate: QuizDetailDelegate)
        case onPracticePressed(quizId: String)
        case onQuestionPressed(questionId: String, index: Int)
        case onDeleteQuestionPressed(questionId: String)
        case onDeleteQuestionSuccess(questionId: String)
        case onDeleteQuestionFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                     return "QuizDetailView_Appear"
            case .onDisappear:                  return "QuizDetailView_Disappear"
            case .onPracticePressed:            return "QuizDetailView_Practice_Pressed"
            case .onQuestionPressed:            return "QuizDetailView_Question_Pressed"
            case .onDeleteQuestionPressed:      return "QuizDetailView_DeleteQuestion_Pressed"
            case .onDeleteQuestionSuccess:      return "QuizDetailView_DeleteQuestion_Success"
            case .onDeleteQuestionFail:         return "QuizDetailView_DeleteQuestion_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onPracticePressed(quizId: let quizId):
                return ["quiz_id": quizId]
            case .onQuestionPressed(questionId: let qId, index: let index):
                return ["question_id": qId, "question_index": index]
            case .onDeleteQuestionPressed(questionId: let qId), .onDeleteQuestionSuccess(questionId: let qId):
                return ["question_id": qId]
            case .onDeleteQuestionFail(error: let error):
                return error.eventParameters
            }
        }

        var type: LogType {
            switch self {
            case .onDeleteQuestionFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
