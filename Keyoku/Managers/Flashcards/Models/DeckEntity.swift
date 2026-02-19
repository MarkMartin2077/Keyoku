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
    var colorRaw: String = DeckColor.blue.rawValue
    var imageUrl: String?
    var sourceText: String = ""
    var createdAt: Date = Date.now
    var clickCount: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \FlashcardEntity.deck)
    var flashcards: [FlashcardEntity] = []
    
    var color: DeckColor {
        get { DeckColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }

    init(id: String = UUID().uuidString, name: String, color: DeckColor = .blue, imageUrl: String? = nil, sourceText: String, createdAt: Date = .now, clickCount: Int = 0) {
        self.id = id
        self.name = name
        self.colorRaw = color.rawValue
        self.imageUrl = imageUrl
        self.sourceText = sourceText
        self.createdAt = createdAt
        self.clickCount = clickCount
    }

    convenience init(from model: DeckModel) {
        self.init(id: model.deckId, name: model.name, color: model.color, imageUrl: model.imageUrl, sourceText: model.sourceText, createdAt: model.createdAt, clickCount: model.clickCount)
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
            color: color,
            imageUrl: imageUrl,
            sourceText: sourceText,
            createdAt: createdAt,
            flashcards: flashcards.map { $0.toModel() },
            clickCount: clickCount
        )
    }
}
