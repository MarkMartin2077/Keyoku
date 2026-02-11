//
//  DecksInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol DecksInteractor: GlobalInteractor {
    var decks: [DeckModel] { get }
    func loadDecks()
    func createDeck(name: String, color: DeckColor, sourceText: String) throws
    func deleteDeck(id: String) throws
}

extension CoreInteractor: DecksInteractor { }
