//
//  FlashcardManager.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
@Observable
class FlashcardManager {
    
    private let local: LocalDeckPersistence
    private let logManager: LogManager?
    
    private(set) var decks: [DeckModel] = []
    
    init(services: FlashcardServices, logManager: LogManager? = nil) {
        self.local = services.local
        self.logManager = logManager
    }
    
    // MARK: - Deck Operations
    
    func loadDecks() {
        logManager?.trackEvent(event: Event.loadDecksStart)
        
        do {
            decks = try local.getAllDecks()
            logManager?.trackEvent(event: Event.loadDecksSuccess(count: decks.count))
        } catch {
            logManager?.trackEvent(event: Event.loadDecksFail(error: error))
        }
    }
    
    func getDeck(id: String) -> DeckModel? {
        decks.first { $0.deckId == id }
    }
    
    func createDeck(name: String, color: DeckColor = .blue, sourceText: String) throws {
        logManager?.trackEvent(event: Event.createDeckStart(name: name))
        
        let deck = DeckModel(name: name, color: color, sourceText: sourceText)
        
        do {
            try local.saveDeck(deck: deck)
            decks.insert(deck, at: 0)
            logManager?.trackEvent(event: Event.createDeckSuccess(deck: deck))
        } catch {
            logManager?.trackEvent(event: Event.createDeckFail(error: error))
            throw error
        }
    }
    
    func createDeck(name: String, color: DeckColor = .blue, sourceText: String, flashcards: [FlashcardModel]) throws {
        logManager?.trackEvent(event: Event.createDeckStart(name: name))
        
        let deckId = UUID().uuidString
        let flashcardsWithDeckId = flashcards.map { card in
            FlashcardModel(
                flashcardId: card.flashcardId,
                question: card.question,
                answer: card.answer,
                deckId: deckId
            )
        }
        
        let deck = DeckModel(
            deckId: deckId,
            name: name,
            color: color,
            sourceText: sourceText,
            flashcards: flashcardsWithDeckId
        )
        
        do {
            try local.saveDeck(deck: deck)
            decks.insert(deck, at: 0)
            logManager?.trackEvent(event: Event.createDeckSuccess(deck: deck))
        } catch {
            logManager?.trackEvent(event: Event.createDeckFail(error: error))
            throw error
        }
    }
    
    func updateDeck(_ deck: DeckModel) throws {
        logManager?.trackEvent(event: Event.updateDeckStart(deck: deck))
        
        do {
            try local.saveDeck(deck: deck)
            if let index = decks.firstIndex(where: { $0.deckId == deck.deckId }) {
                decks[index] = deck
            }
            logManager?.trackEvent(event: Event.updateDeckSuccess(deck: deck))
        } catch {
            logManager?.trackEvent(event: Event.updateDeckFail(error: error))
            throw error
        }
    }
    
    func deleteDeck(id: String) throws {
        logManager?.trackEvent(event: Event.deleteDeckStart(deckId: id))
        
        do {
            try local.deleteDeck(id: id)
            decks.removeAll { $0.deckId == id }
            logManager?.trackEvent(event: Event.deleteDeckSuccess(deckId: id))
        } catch {
            logManager?.trackEvent(event: Event.deleteDeckFail(error: error))
            throw error
        }
    }
    
    // MARK: - Flashcard Operations
    
    func addFlashcard(question: String, answer: String, toDeckId: String) throws {
        logManager?.trackEvent(event: Event.addFlashcardStart(deckId: toDeckId))
        
        let flashcard = FlashcardModel(question: question, answer: answer, deckId: toDeckId)
        
        do {
            try local.addFlashcard(flashcard: flashcard, toDeckId: toDeckId)
            
            // Update local state
            if let deckIndex = decks.firstIndex(where: { $0.deckId == toDeckId }) {
                let deck = decks[deckIndex]
                let updatedDeck = DeckModel(
                    deckId: deck.deckId,
                    name: deck.name,
                    color: deck.color,
                    sourceText: deck.sourceText,
                    createdAt: deck.createdAt,
                    flashcards: deck.flashcards + [flashcard]
                )
                decks[deckIndex] = updatedDeck
            }
            
            logManager?.trackEvent(event: Event.addFlashcardSuccess(flashcard: flashcard))
        } catch {
            logManager?.trackEvent(event: Event.addFlashcardFail(error: error))
            throw error
        }
    }
    
    func deleteFlashcard(id: String, fromDeckId: String) throws {
        logManager?.trackEvent(event: Event.deleteFlashcardStart(flashcardId: id))
        
        do {
            try local.deleteFlashcard(id: id)
            
            // Update local state
            if let deckIndex = decks.firstIndex(where: { $0.deckId == fromDeckId }) {
                let deck = decks[deckIndex]
                let updatedDeck = DeckModel(
                    deckId: deck.deckId,
                    name: deck.name,
                    color: deck.color,
                    sourceText: deck.sourceText,
                    createdAt: deck.createdAt,
                    flashcards: deck.flashcards.filter { $0.flashcardId != id }
                )
                decks[deckIndex] = updatedDeck
            }
            
            logManager?.trackEvent(event: Event.deleteFlashcardSuccess(flashcardId: id))
        } catch {
            logManager?.trackEvent(event: Event.deleteFlashcardFail(error: error))
            throw error
        }
    }
    
    // MARK: - Events
    
    enum Event: LoggableEvent {
        case loadDecksStart
        case loadDecksSuccess(count: Int)
        case loadDecksFail(error: Error)
        case createDeckStart(name: String)
        case createDeckSuccess(deck: DeckModel)
        case createDeckFail(error: Error)
        case updateDeckStart(deck: DeckModel)
        case updateDeckSuccess(deck: DeckModel)
        case updateDeckFail(error: Error)
        case deleteDeckStart(deckId: String)
        case deleteDeckSuccess(deckId: String)
        case deleteDeckFail(error: Error)
        case addFlashcardStart(deckId: String)
        case addFlashcardSuccess(flashcard: FlashcardModel)
        case addFlashcardFail(error: Error)
        case deleteFlashcardStart(flashcardId: String)
        case deleteFlashcardSuccess(flashcardId: String)
        case deleteFlashcardFail(error: Error)
        
        var eventName: String {
            switch self {
            case .loadDecksStart:           return "FlashcardMan_LoadDecks_Start"
            case .loadDecksSuccess:         return "FlashcardMan_LoadDecks_Success"
            case .loadDecksFail:            return "FlashcardMan_LoadDecks_Fail"
            case .createDeckStart:          return "FlashcardMan_CreateDeck_Start"
            case .createDeckSuccess:        return "FlashcardMan_CreateDeck_Success"
            case .createDeckFail:           return "FlashcardMan_CreateDeck_Fail"
            case .updateDeckStart:          return "FlashcardMan_UpdateDeck_Start"
            case .updateDeckSuccess:        return "FlashcardMan_UpdateDeck_Success"
            case .updateDeckFail:           return "FlashcardMan_UpdateDeck_Fail"
            case .deleteDeckStart:          return "FlashcardMan_DeleteDeck_Start"
            case .deleteDeckSuccess:        return "FlashcardMan_DeleteDeck_Success"
            case .deleteDeckFail:           return "FlashcardMan_DeleteDeck_Fail"
            case .addFlashcardStart:        return "FlashcardMan_AddFlashcard_Start"
            case .addFlashcardSuccess:      return "FlashcardMan_AddFlashcard_Success"
            case .addFlashcardFail:         return "FlashcardMan_AddFlashcard_Fail"
            case .deleteFlashcardStart:     return "FlashcardMan_DeleteFlashcard_Start"
            case .deleteFlashcardSuccess:   return "FlashcardMan_DeleteFlashcard_Success"
            case .deleteFlashcardFail:      return "FlashcardMan_DeleteFlashcard_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .loadDecksSuccess(count: let count):
                return ["deck_count": count]
            case .createDeckStart(name: let name):
                return ["deck_name": name]
            case .createDeckSuccess(deck: let deck), .updateDeckStart(deck: let deck), .updateDeckSuccess(deck: let deck):
                return deck.eventParameters
            case .deleteDeckStart(deckId: let id), .deleteDeckSuccess(deckId: let id):
                return ["deck_id": id]
            case .addFlashcardStart(deckId: let id):
                return ["deck_id": id]
            case .addFlashcardSuccess(flashcard: let flashcard):
                return flashcard.eventParameters
            case .deleteFlashcardStart(flashcardId: let id), .deleteFlashcardSuccess(flashcardId: let id):
                return ["flashcard_id": id]
            case .loadDecksFail(error: let error), .createDeckFail(error: let error), .updateDeckFail(error: let error), .deleteDeckFail(error: let error), .addFlashcardFail(error: let error), .deleteFlashcardFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .loadDecksFail, .createDeckFail, .updateDeckFail, .deleteDeckFail, .addFlashcardFail, .deleteFlashcardFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
