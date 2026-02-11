//
//  CreateDeckInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol CreateDeckInteractor: GlobalInteractor {
    func createDeck(name: String, color: DeckColor, sourceText: String) throws
    func createDeck(name: String, color: DeckColor, sourceText: String, flashcards: [FlashcardModel]) throws
}

extension CoreInteractor: CreateDeckInteractor { }
