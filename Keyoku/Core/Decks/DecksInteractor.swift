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
    func createDeck(name: String, color: DeckColor, imageUrl: String?, sourceText: String) throws
    func deleteDeck(id: String) throws
    var isPremium: Bool { get }
    var freeTierDeckLimit: Int { get }
    var currentUser: UserModel? { get }
    var deckSortOption: DeckSortOption { get }
    func saveDeckSortOption(_ option: DeckSortOption)
    func recordPaywallShown()
}

extension CoreInteractor: DecksInteractor { }
