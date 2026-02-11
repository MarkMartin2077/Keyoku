//
//  LocalDeckPersistence.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol DeckService {
    func getAllDecks() async throws -> [DeckModel]
    func getDeck(id: String) async throws -> DeckModel?
    func saveDeck(deck: DeckModel, image: UIImage) async throws
    func deleteDeck(id: String) async throws
    func addFlashcard(flashcard: FlashcardModel, toDeckId: String) async throws
    func deleteFlashcard(id: String) async throws
}
