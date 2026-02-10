//
//  LocalDeckPersistence.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import Foundation

@MainActor
protocol LocalDeckPersistence {
    func getAllDecks() throws -> [DeckModel]
    func getDeck(id: String) throws -> DeckModel?
    func saveDeck(deck: DeckModel) throws
    func deleteDeck(id: String) throws
    func addFlashcard(flashcard: FlashcardModel, toDeckId: String) throws
    func deleteFlashcard(id: String) throws
}
