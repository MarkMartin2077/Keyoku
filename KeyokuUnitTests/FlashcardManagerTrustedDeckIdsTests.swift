//
//  FlashcardManagerTrustedDeckIdsTests.swift
//  KeyokuUnitTests
//

// `trustedDeckIds` tells the quiz sign-in which decks really exist, so it can
// delete quizzes whose deck is gone. It must never be missing a deck that exists
// remotely: a missing id gets that deck's quizzes deleted from Firestore.

import Testing
@testable import Keyoku

@Suite("FlashcardManager — Trusted Deck Ids")
@MainActor
struct FlashcardManagerTrustedDeckIdsTests {

    private func makeManager(local: MockDeckPersistence, remote: MockRemoteDeckService) -> FlashcardManager {
        FlashcardManager(services: MockFlashcardServices(local: local, remote: remote))
    }

    @Test("Trusted deck ids are nil when the remote fetch fails")
    func remoteFetchFails() async throws {
        // GIVEN — local has decks but remote is unreachable
        let manager = makeManager(
            local: MockDeckPersistence(decks: DeckModel.mocks),
            remote: MockRemoteDeckService(decks: DeckModel.mocks, shouldFail: true)
        )

        // WHEN
        try await manager.logIn(userId: "user1")

        // THEN — the local fallback can't vouch for the full deck list
        #expect(manager.trustedDeckIds == nil)
    }

    @Test("Trusted deck ids keep the remote decks when local save and load fail")
    func localStoreFails() async throws {
        // GIVEN — remote returns decks but the local store can't save or read
        let remoteDecks = DeckModel.mocks
        let manager = makeManager(
            local: MockDeckPersistence(decks: [], shouldFail: true),
            remote: MockRemoteDeckService(decks: remoteDecks)
        )

        // WHEN
        try await manager.logIn(userId: "user1")

        // THEN
        #expect(manager.decks.isEmpty)
        #expect(manager.trustedDeckIds == Set(remoteDecks.map(\.deckId)))
    }

    @Test("Trusted deck ids are the remote deck ids plus the local ones")
    func remoteUnionLocal() async throws {
        // GIVEN — one deck only on this device, another only on remote
        let localDeck = DeckModel.mocks[0]
        let remoteDeck = DeckModel.mocks[1]
        let manager = makeManager(
            local: MockDeckPersistence(decks: [localDeck]),
            remote: MockRemoteDeckService(decks: [remoteDeck])
        )

        // WHEN
        try await manager.logIn(userId: "user1")

        // THEN
        #expect(manager.trustedDeckIds == [localDeck.deckId, remoteDeck.deckId])
    }

    @Test("Trusted deck ids are nil after signing out")
    func signOutClears() async throws {
        let manager = makeManager(
            local: MockDeckPersistence(decks: []),
            remote: MockRemoteDeckService(decks: DeckModel.mocks)
        )
        try await manager.logIn(userId: "user1")

        manager.signOut()

        #expect(manager.trustedDeckIds == nil)
    }
}
