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
    
    var decks: [DeckModel] {
        interactor.decks
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
    
    func onCreateDeckPressed(name: String) {
        interactor.trackEvent(event: Event.onCreateDeckPressed(name: name))
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            interactor.trackEvent(event: Event.onCreateDeckEmptyName)
            return
        }
        
        do {
            try interactor.createDeck(name: name, sourceText: "")
            interactor.trackEvent(event: Event.onCreateDeckSuccess(name: name))
        } catch {
            interactor.trackEvent(event: Event.onCreateDeckFail(error: error))
        }
    }
    
    func onDeckPressed(deck: DeckModel) {
        interactor.trackEvent(event: Event.onDeckPressed(deck: deck))
        router.showDeckDetailView(deck: deck)
    }
    
    func onDeleteDecks(at indexSet: IndexSet) {
        for index in indexSet {
            let deck = decks[index]
            interactor.trackEvent(event: Event.onDeleteDeckPressed(deck: deck))
            
            do {
                try interactor.deleteDeck(id: deck.deckId)
                interactor.trackEvent(event: Event.onDeleteDeckSuccess(deckId: deck.deckId))
            } catch {
                interactor.trackEvent(event: Event.onDeleteDeckFail(error: error))
            }
        }
    }
}

extension DecksPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: DecksDelegate)
        case onDisappear(delegate: DecksDelegate)
        case onCreateDeckPressed(name: String)
        case onCreateDeckEmptyName
        case onCreateDeckSuccess(name: String)
        case onCreateDeckFail(error: Error)
        case onDeckPressed(deck: DeckModel)
        case onDeleteDeckPressed(deck: DeckModel)
        case onDeleteDeckSuccess(deckId: String)
        case onDeleteDeckFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                 return "DecksView_Appear"
            case .onDisappear:              return "DecksView_Disappear"
            case .onCreateDeckPressed:      return "DecksView_CreateDeck_Pressed"
            case .onCreateDeckEmptyName:    return "DecksView_CreateDeck_EmptyName"
            case .onCreateDeckSuccess:      return "DecksView_CreateDeck_Success"
            case .onCreateDeckFail:         return "DecksView_CreateDeck_Fail"
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
            case .onCreateDeckPressed(name: let name), .onCreateDeckSuccess(name: let name):
                return ["deck_name": name]
            case .onDeckPressed(deck: let deck), .onDeleteDeckPressed(deck: let deck):
                return deck.eventParameters
            case .onDeleteDeckSuccess(deckId: let deckId):
                return ["deck_id": deckId]
            case .onCreateDeckFail(error: let error), .onDeleteDeckFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .onCreateDeckFail, .onDeleteDeckFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
