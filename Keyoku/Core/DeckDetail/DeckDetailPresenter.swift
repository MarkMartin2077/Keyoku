//
//  DeckDetailPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@Observable
@MainActor
class DeckDetailPresenter {
    
    private let interactor: DeckDetailInteractor
    private let router: DeckDetailRouter
    private let deckId: String
    
    let deckName: String
    let deckColor: DeckColor
    
    private var deck: DeckModel? {
        interactor.getDeck(id: deckId)
    }
    
    var flashcards: [FlashcardModel] {
        deck?.flashcards ?? []
    }
    
    init(interactor: DeckDetailInteractor, router: DeckDetailRouter, deck: DeckModel) {
        self.interactor = interactor
        self.router = router
        self.deckId = deck.deckId
        self.deckName = deck.name
        self.deckColor = deck.color
    }
    
    func onViewAppear(delegate: DeckDetailDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: DeckDetailDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onPracticePressed() {
        guard let deck = deck else { return }
        interactor.trackEvent(event: Event.onPracticePressed)
        router.showPracticeView(deck: deck)
    }
    
    func onAddCardPressed(question: String, answer: String) {
        interactor.trackEvent(event: Event.onAddCardPressed)
        
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuestion.isEmpty, !trimmedAnswer.isEmpty else {
            interactor.trackEvent(event: Event.onAddCardEmptyFields)
            return
        }
        
        do {
            try interactor.addFlashcard(question: trimmedQuestion, answer: trimmedAnswer, toDeckId: deckId)
            interactor.trackEvent(event: Event.onAddCardSuccess)
        } catch {
            interactor.trackEvent(event: Event.onAddCardFail(error: error))
        }
    }
    
    func onDeleteFlashcards(at indexSet: IndexSet) {
        for index in indexSet {
            let flashcard = flashcards[index]
            interactor.trackEvent(event: Event.onDeleteCardPressed(flashcard: flashcard))
            
            do {
                try interactor.deleteFlashcard(id: flashcard.flashcardId, fromDeckId: deckId)
                interactor.trackEvent(event: Event.onDeleteCardSuccess(flashcardId: flashcard.flashcardId))
            } catch {
                interactor.trackEvent(event: Event.onDeleteCardFail(error: error))
            }
        }
    }
}

extension DeckDetailPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: DeckDetailDelegate)
        case onDisappear(delegate: DeckDetailDelegate)
        case onPracticePressed
        case onAddCardPressed
        case onAddCardEmptyFields
        case onAddCardSuccess
        case onAddCardFail(error: Error)
        case onDeleteCardPressed(flashcard: FlashcardModel)
        case onDeleteCardSuccess(flashcardId: String)
        case onDeleteCardFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:                 return "DeckDetailView_Appear"
            case .onDisappear:              return "DeckDetailView_Disappear"
            case .onPracticePressed:        return "DeckDetailView_Practice_Pressed"
            case .onAddCardPressed:         return "DeckDetailView_AddCard_Pressed"
            case .onAddCardEmptyFields:     return "DeckDetailView_AddCard_EmptyFields"
            case .onAddCardSuccess:         return "DeckDetailView_AddCard_Success"
            case .onAddCardFail:            return "DeckDetailView_AddCard_Fail"
            case .onDeleteCardPressed:      return "DeckDetailView_DeleteCard_Pressed"
            case .onDeleteCardSuccess:      return "DeckDetailView_DeleteCard_Success"
            case .onDeleteCardFail:         return "DeckDetailView_DeleteCard_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onDeleteCardPressed(flashcard: let flashcard):
                return flashcard.eventParameters
            case .onDeleteCardSuccess(flashcardId: let id):
                return ["flashcard_id": id]
            case .onAddCardFail(error: let error), .onDeleteCardFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .onAddCardFail, .onDeleteCardFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
