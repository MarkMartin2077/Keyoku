//
//  RemoteDeckService.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation

@MainActor
protocol RemoteDeckService: Sendable {
    func getAllDecks(userId: String) async throws -> [DeckModel]
    func getDeck(userId: String, deckId: String) async throws -> DeckModel
    func saveDeck(userId: String, deck: DeckModel) async throws
    func deleteDeck(userId: String, deckId: String) async throws
}
