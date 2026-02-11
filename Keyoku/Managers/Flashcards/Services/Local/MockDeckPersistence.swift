//
//  MockDeckPersistence.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import Foundation

@MainActor
class MockDeckPersistence: LocalDeckPersistence {
    private var decks: [DeckModel]
    
    init(decks: [DeckModel] = DeckModel.mocks) {
        self.decks = decks
    }
    
    func getAllDecks() throws -> [DeckModel] {
        decks.sorted { $0.createdAt > $1.createdAt }
    }
    
    func getDeck(id: String) throws -> DeckModel? {
        decks.first { $0.deckId == id }
    }
    
    func saveDeck(deck: DeckModel) throws {
        if let index = decks.firstIndex(where: { $0.deckId == deck.deckId }) {
            decks[index] = deck
        } else {
            decks.append(deck)
        }
    }
    
    func deleteDeck(id: String) throws {
        decks.removeAll { $0.deckId == id }
    }
    
    func addFlashcard(flashcard: FlashcardModel, toDeckId: String) throws {
        guard let index = decks.firstIndex(where: { $0.deckId == toDeckId }) else {
            throw DeckPersistenceError.deckNotFound
        }
        
        let deck = decks[index]
        let updatedDeck = DeckModel(
            deckId: deck.deckId,
            name: deck.name,
            imageUrl: deck.imageUrl,
            sourceText: deck.sourceText,
            createdAt: deck.createdAt,
            flashcards: deck.flashcards + [flashcard]
        )
        decks[index] = updatedDeck
    }
    
    func deleteFlashcard(id: String) throws {
        for (deckIndex, deck) in decks.enumerated() where deck.flashcards.contains(where: { $0.flashcardId == id }) {
            let updatedDeck = DeckModel(
                deckId: deck.deckId,
                name: deck.name,
                imageUrl: deck.imageUrl,
                sourceText: deck.sourceText,
                createdAt: deck.createdAt,
                flashcards: deck.flashcards.filter { $0.flashcardId != id }
            )
            decks[deckIndex] = updatedDeck
            return
        }
    }
}
