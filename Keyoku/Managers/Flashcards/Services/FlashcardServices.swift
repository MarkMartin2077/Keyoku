//
//  FlashcardServices.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import Foundation

@MainActor
protocol FlashcardServices {
    var local: DeckService { get }
    var remote: RemoteDeckService { get }
}

@MainActor
struct MockFlashcardServices: FlashcardServices {
    let local: DeckService
    let remote: RemoteDeckService

    init(decks: [DeckModel] = DeckModel.mocks) {
        self.local = MockDeckPersistence(decks: decks)
        self.remote = MockRemoteDeckService(decks: decks)
    }
}

@MainActor
struct ProductionFlashcardServices: FlashcardServices {
    let local: DeckService = SwiftDataDeckPersistence()
    let remote: RemoteDeckService = FirebaseDeckService()
}
