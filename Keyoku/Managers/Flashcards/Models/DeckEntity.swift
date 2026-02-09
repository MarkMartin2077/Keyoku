//
//  DeckEntity.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import Foundation
import SwiftData

@Model
class DeckEntity {
    @Attribute(.unique) var id: String = UUID().uuidString
    var name: String = ""
    var sourceText: String = ""
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \FlashcardEntity.deck)
    var flashcards: [FlashcardEntity] = []

    init(id: String = UUID().uuidString, name: String, sourceText: String) {
        self.id = id
        self.name = name
        self.sourceText = sourceText
        self.createdAt = .now
    }
}
