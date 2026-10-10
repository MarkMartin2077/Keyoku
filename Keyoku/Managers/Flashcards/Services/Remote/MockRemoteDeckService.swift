//
//  MockRemoteDeckService.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation

struct MockRemoteDeckService: RemoteDeckService {

    private var decks: [DeckModel]
    private let shouldFail: Bool

    /// - Parameter shouldFail: When `true`, fetching all decks throws, like being offline.
    init(decks: [DeckModel] = [], shouldFail: Bool = false) {
        self.decks = decks
        self.shouldFail = shouldFail
    }

    func getAllDecks(userId: String) async throws -> [DeckModel] {
        if shouldFail { throw AppError("Mock remote fetch failed") }
        return decks
    }

    func getDeck(userId: String, deckId: String) async throws -> DeckModel {
        guard let deck = decks.first(where: { $0.deckId == deckId }) else {
            throw NSError(domain: "MockRemoteDeckService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Deck not found"])
        }
        return deck
    }

    func saveDeck(userId: String, deck: DeckModel) async throws {
        // No-op for mock
    }

    func deleteDeck(userId: String, deckId: String) async throws {
        // No-op for mock
    }
}
