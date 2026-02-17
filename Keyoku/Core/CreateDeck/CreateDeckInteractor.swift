//
//  CreateDeckInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol CreateDeckInteractor: GlobalInteractor {
    var decks: [DeckModel] { get }
    var currentUser: UserModel? { get }
    func createDeck(name: String, color: DeckColor, imageUrl: String?, sourceText: String) throws
    func createDeck(name: String, color: DeckColor, imageUrl: String?, sourceText: String, flashcards: [FlashcardModel]) throws
    func saveDeckImage(data: Data) throws -> String
    func saveFirstDeckCreated() async throws
}

extension CoreInteractor: CreateDeckInteractor { }
