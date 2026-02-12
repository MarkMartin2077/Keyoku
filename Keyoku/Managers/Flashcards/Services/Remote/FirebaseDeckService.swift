//
//  FirebaseDeckService.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import FirebaseFirestore
import SwiftfulFirestore

struct FirebaseDeckService: RemoteDeckService {

    private func collection(userId: String) -> CollectionReference {
        Firestore.firestore().collection("users").document(userId).collection("decks")
    }

    func getAllDecks(userId: String) async throws -> [DeckModel] {
        try await collection(userId: userId).getAllDocuments()
    }

    func getDeck(userId: String, deckId: String) async throws -> DeckModel {
        try await collection(userId: userId).getDocument(id: deckId)
    }

    func saveDeck(userId: String, deck: DeckModel) async throws {
        try collection(userId: userId).document(deck.deckId).setData(from: deck, merge: true)
    }

    func deleteDeck(userId: String, deckId: String) async throws {
        try await collection(userId: userId).document(deckId).delete()
    }
}
