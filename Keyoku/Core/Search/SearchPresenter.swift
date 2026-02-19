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

        let matched = interactor.decks.filter { deck in
            if deck.name.lowercased().localizedStandardContains(query) {
                return true
            }
            return deck.flashcards.contains { card in
                card.question.lowercased().localizedStandardContains(query) ||
                card.answer.lowercased().localizedStandardContains(query)
            }
        }

        return matched.sorted { deck1, deck2 in
            let d1Cards = matchingCardCount(in: deck1)
            let d2Cards = matchingCardCount(in: deck2)
            if d1Cards != d2Cards {
                return d1Cards > d2Cards
            }
            return false
        }
    }

    func matchingCardCount(in deck: DeckModel) -> Int {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return 0 }
        return deck.flashcards.filter { card in
            card.question.lowercased().localizedStandardContains(query) ||
            card.answer.lowercased().localizedStandardContains(query)
        }.count
    }

    init(interactor: SearchInteractor, router: SearchRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: SearchDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        interactor.loadDecks()
    }

    func onViewDisappear(delegate: SearchDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onDeckPressed(deck: DeckModel) {
        interactor.trackEvent(event: Event.onDeckPressed(deck: deck))
        router.showDeckDetailView(deck: deck)
    }

}

extension SearchPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: SearchDelegate)
        case onDisappear(delegate: SearchDelegate)
        case onDeckPressed(deck: DeckModel)

        var eventName: String {
            switch self {
            case .onAppear:         return "SearchView_Appear"
            case .onDisappear:      return "SearchView_Disappear"
            case .onDeckPressed:    return "SearchView_Deck_Pressed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onDeckPressed(deck: let deck):
                return deck.eventParameters
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
