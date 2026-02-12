//
//  QuizzesPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@Observable
@MainActor
class QuizzesPresenter {

    private let interactor: QuizzesInteractor
    private let router: QuizzesRouter

    var searchText = ""

    var quizzes: [QuizModel] {
        interactor.quizzes
    }

    var filteredQuizzes: [QuizModel] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return quizzes }
        return quizzes.filter { $0.name.lowercased().contains(query) }
    }

    init(interactor: QuizzesInteractor, router: QuizzesRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: QuizzesDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        interactor.loadQuizzes()
    }

    func onViewDisappear(delegate: QuizzesDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onAddQuizPressed() {
        interactor.trackEvent(event: Event.onAddQuizPressed)
        router.showCreateContentView(defaultContentType: .quiz)
    }

    func onQuizPressed(quiz: QuizModel) {
        interactor.trackEvent(event: Event.onQuizPressed(quiz: quiz))
        router.showQuizView(quiz: quiz)
    }

    func onDeleteQuizzes(at indexSet: IndexSet) {
        for index in indexSet {
            let quiz = filteredQuizzes[index]
            interactor.trackEvent(event: Event.onDeleteQuizPressed(quiz: quiz))

            do {
                try interactor.deleteQuiz(id: quiz.quizId)
                interactor.trackEvent(event: Event.onDeleteQuizSuccess(quizId: quiz.quizId))
            } catch {
                interactor.trackEvent(event: Event.onDeleteQuizFail(error: error))
                router.showAlert(error: error)
            }
        }
    }
}

extension QuizzesPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: QuizzesDelegate)
        case onDisappear(delegate: QuizzesDelegate)
        case onAddQuizPressed
        case onQuizPressed(quiz: QuizModel)
        case onDeleteQuizPressed(quiz: QuizModel)
        case onDeleteQuizSuccess(quizId: String)
        case onDeleteQuizFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                 return "QuizzesView_Appear"
            case .onDisappear:              return "QuizzesView_Disappear"
            case .onAddQuizPressed:         return "QuizzesView_AddQuiz_Pressed"
            case .onQuizPressed:            return "QuizzesView_Quiz_Pressed"
            case .onDeleteQuizPressed:      return "QuizzesView_DeleteQuiz_Pressed"
            case .onDeleteQuizSuccess:      return "QuizzesView_DeleteQuiz_Success"
            case .onDeleteQuizFail:         return "QuizzesView_DeleteQuiz_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onQuizPressed(quiz: let quiz), .onDeleteQuizPressed(quiz: let quiz):
                return quiz.eventParameters
            case .onDeleteQuizSuccess(quizId: let quizId):
                return ["quiz_id": quizId]
            case .onDeleteQuizFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onDeleteQuizFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
