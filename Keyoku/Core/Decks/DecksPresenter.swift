//
//  DecksPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@Observable
@MainActor
class DecksPresenter {
    
    private let interactor: DecksInteractor
    private let router: DecksRouter

    var searchText = ""

    var decks: [DeckModel] {
        interactor.decks
    }

    var filteredDecks: [DeckModel] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return decks }
        return decks.filter { $0.name.lowercased().contains(query) }
    }

    init(interactor: DecksInteractor, router: DecksRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: DecksDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        interactor.loadDecks()
    }
    
    func onViewDisappear(delegate: DecksDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onAddDeckPressed() {
        interactor.trackEvent(event: Event.onAddDeckPressed)
        router.showCreateContentView(defaultContentType: .flashcards)
    }
    
    func onDeckPressed(deck: DeckModel) {
        interactor.trackEvent(event: Event.onDeckPressed(deck: deck))
        router.showDeckDetailView(deck: deck)
    }
    
    func onDeleteDecks(at indexSet: IndexSet) {
        for index in indexSet {
            let deck = filteredDecks[index]
            interactor.trackEvent(event: Event.onDeleteDeckPressed(deck: deck))
            
            do {
                try interactor.deleteDeck(id: deck.deckId)
                interactor.trackEvent(event: Event.onDeleteDeckSuccess(deckId: deck.deckId))
            } catch {
                interactor.trackEvent(event: Event.onDeleteDeckFail(error: error))
                router.showAlert(error: error)
            }
        }
    }
}

extension DecksPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: DecksDelegate)
        case onDisappear(delegate: DecksDelegate)
        case onAddDeckPressed
        case onDeckPressed(deck: DeckModel)
        case onDeleteDeckPressed(deck: DeckModel)
        case onDeleteDeckSuccess(deckId: String)
        case onDeleteDeckFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                 return "DecksView_Appear"
            case .onDisappear:              return "DecksView_Disappear"
            case .onAddDeckPressed:         return "DecksView_AddDeck_Pressed"
            case .onDeckPressed:            return "DecksView_Deck_Pressed"
            case .onDeleteDeckPressed:      return "DecksView_DeleteDeck_Pressed"
            case .onDeleteDeckSuccess:      return "DecksView_DeleteDeck_Success"
            case .onDeleteDeckFail:         return "DecksView_DeleteDeck_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onDeckPressed(deck: let deck), .onDeleteDeckPressed(deck: let deck):
                return deck.eventParameters
            case .onDeleteDeckSuccess(deckId: let deckId):
                return ["deck_id": deckId]
            case .onDeleteDeckFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .onDeleteDeckFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
