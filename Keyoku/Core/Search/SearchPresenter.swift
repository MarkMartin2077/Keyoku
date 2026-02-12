//
//  SearchPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@Observable
@MainActor
class SearchPresenter {

    private let interactor: SearchInteractor
    private let router: SearchRouter

    var searchText = ""

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var filteredDecks: [DeckModel] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return interactor.decks.filter { $0.name.lowercased().contains(query) }
    }

    var filteredQuizzes: [QuizModel] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return interactor.quizzes.filter { $0.name.lowercased().contains(query) }
    }

    init(interactor: SearchInteractor, router: SearchRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: SearchDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        interactor.loadDecks()
        interactor.loadQuizzes()
    }

    func onViewDisappear(delegate: SearchDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onDeckPressed(deck: DeckModel) {
        interactor.trackEvent(event: Event.onDeckPressed(deck: deck))
        router.showDeckDetailView(deck: deck)
    }

    func onQuizPressed(quiz: QuizModel) {
        interactor.trackEvent(event: Event.onQuizPressed(quiz: quiz))
        router.showQuizView(quiz: quiz)
    }
}

extension SearchPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: SearchDelegate)
        case onDisappear(delegate: SearchDelegate)
        case onDeckPressed(deck: DeckModel)
        case onQuizPressed(quiz: QuizModel)

        var eventName: String {
            switch self {
            case .onAppear:         return "SearchView_Appear"
            case .onDisappear:      return "SearchView_Disappear"
            case .onDeckPressed:    return "SearchView_Deck_Pressed"
            case .onQuizPressed:    return "SearchView_Quiz_Pressed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onDeckPressed(deck: let deck):
                return deck.eventParameters
            case .onQuizPressed(quiz: let quiz):
                return quiz.eventParameters
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
