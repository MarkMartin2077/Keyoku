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

    init(id: String = UUID().uuidString, name: String, sourceText: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.sourceText = sourceText
        self.createdAt = createdAt
    }

    convenience init(from model: DeckModel) {
        self.init(id: model.deckId, name: model.name, sourceText: model.sourceText, createdAt: model.createdAt)
        self.flashcards = model.flashcards.map { flashcard in
            let entity = FlashcardEntity(from: flashcard)
            entity.deck = self
            return entity
        }
    }

    func toModel() -> DeckModel {
        DeckModel(
            deckId: id,
            name: name,
            sourceText: sourceText,
            createdAt: createdAt,
            flashcards: flashcards.map { $0.toModel() }
        )
    }
}
