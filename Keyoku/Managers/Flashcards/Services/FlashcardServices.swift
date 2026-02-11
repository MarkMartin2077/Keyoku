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
}

@MainActor
struct MockFlashcardServices: FlashcardServices {
    let local: DeckService
    
    init(decks: [DeckModel] = DeckModel.mocks) {
        self.local = MockDeckPersistence(decks: decks)
    }
}

@MainActor
struct ProductionFlashcardServices: FlashcardServices {
    let local: DeckService = SwiftDataDeckPersistence()
}
