//
//  SearchPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

/// Global search presenter that filters across deck names and flashcard content.
///
/// Matches against deck names, flashcard questions, and flashcard answers. Results are
/// ranked by the number of matching cards within each deck.
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

    func onSearchSubmitted() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        interactor.trackEvent(event: Event.onSearchSubmitted(query: query, resultCount: filteredDecks.count))
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
        case onSearchSubmitted(query: String, resultCount: Int)
        case onDeckPressed(deck: DeckModel)

        var eventName: String {
            switch self {
            case .onAppear:         return "SearchView_Appear"
            case .onDisappear:      return "SearchView_Disappear"
            case .onSearchSubmitted: return "SearchView_Search_Submitted"
            case .onDeckPressed:     return "SearchView_Deck_Pressed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onSearchSubmitted(query: let query, resultCount: let count):
                return ["search_query": query, "result_count": count]
            case .onDeckPressed(deck: let deck):
                return deck.eventParameters
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
