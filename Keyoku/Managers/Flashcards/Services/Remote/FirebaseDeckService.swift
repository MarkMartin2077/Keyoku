//
//  FirebaseDeckService.swift
//  Keyoku
//
//  Created by Mark Martin on 2/11/26.
//

import FirebaseFirestore
import SwiftfulFirestore

@MainActor
class FirebaseDeckService: DeckService {
    var collection: CollectionReference {
        Firestore.firestore().collection("decks")
    }
    
    func getAllDecks() async throws -> [DeckModel] {
        try await collection.limit(to: 50).getAllDocuments().first(upTo: 5) ?? []
    }
    
    func getDeck(id: String) async throws -> DeckModel? {
        try await collection.getDocument(id: id)
    }
    
    func saveDeck(deck: DeckModel, image: UIImage) async throws {
        let path = "decks/\(deck.id)"
        let url = try await FirebaseImageUploadService().uploadImage(image: image, path: path)
        
        var deck = deck
        deck.updateDeckImage(imageName: url.absoluteString)
        try collection.document(deck.deckId).setData(from: deck, merge: true)
    }
    
    func deleteDeck(id: String) async throws {
        
    }
    
    func addFlashcard(flashcard: FlashcardModel, toDeckId: String) async throws {
        
    }
    
    func deleteFlashcard(id: String) async throws {
        
    }
}
