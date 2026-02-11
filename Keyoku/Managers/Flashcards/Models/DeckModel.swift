//
//  DeckModel.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import Foundation
import IdentifiableByString

struct DeckModel: StringIdentifiable, Codable, Sendable {
    var id: String {
        deckId
    }

    let deckId: String
    let name: String
    let color: DeckColor
    private(set) var imageUrl: String?
    let sourceText: String
    let createdAt: Date
    let flashcards: [FlashcardModel]

    init(
        deckId: String = UUID().uuidString,
        name: String,
        color: DeckColor = .blue,
        imageUrl: String? = nil,
        sourceText: String,
        createdAt: Date = .now,
        flashcards: [FlashcardModel] = []
    ) {
        self.deckId = deckId
        self.name = name
        self.color = color
        self.imageUrl = imageUrl
        self.sourceText = sourceText
        self.createdAt = createdAt
        self.flashcards = flashcards
    }

    init(entity: DeckEntity) {
        self.deckId = entity.id
        self.name = entity.name
        self.color = entity.color
        self.imageUrl = entity.imageUrl
        self.sourceText = entity.sourceText
        self.createdAt = entity.createdAt
        self.flashcards = entity.flashcards.map { FlashcardModel(entity: $0) }
    }
    
    mutating func updateDeckImage(imageName: String) {
        imageUrl = imageName
    }

    enum CodingKeys: String, CodingKey {
        case deckId = "deck_id"
        case name
        case color
        case imageUrl = "image_url"
        case sourceText = "source_text"
        case createdAt = "created_at"
        case flashcards
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "deck_\(CodingKeys.deckId.rawValue)": deckId,
            "deck_\(CodingKeys.name.rawValue)": name,
            "deck_\(CodingKeys.color.rawValue)": color.rawValue,
            "deck_\(CodingKeys.imageUrl.rawValue)": imageUrl,
            "deck_\(CodingKeys.sourceText.rawValue)": sourceText,
            "deck_\(CodingKeys.createdAt.rawValue)": createdAt,
            "deck_flashcard_count": flashcards.count
        ]
        return dict.compactMapValues({ $0 })
    }

    var imageFileURL: URL? {
        guard let imageUrl else { return nil }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(imageUrl)
    }

    func toEntity() -> DeckEntity {
        let entity = DeckEntity(id: deckId, name: name, color: color, imageUrl: imageUrl, sourceText: sourceText, createdAt: createdAt)
        entity.flashcards = flashcards.map { flashcard in
            let flashcardEntity = flashcard.toEntity()
            flashcardEntity.deck = entity
            return flashcardEntity
        }
        return entity
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        let now = Date()
        return [
            DeckModel(
                deckId: "deck1",
                name: "Japanese Basics",
                color: .red,
                sourceText: "Common Japanese phrases and vocabulary",
                createdAt: now,
                flashcards: Array(FlashcardModel.mocks.prefix(3))
            ),
            DeckModel(
                deckId: "deck2",
                name: "Math Fundamentals",
                color: .blue,
                sourceText: "Basic math concepts",
                createdAt: now.addingTimeInterval(-86400),
                flashcards: [FlashcardModel.mocks[3]]
            ),
            DeckModel(
                deckId: "deck3",
                name: "Empty Deck",
                color: .green,
                sourceText: "A deck with no cards yet",
                createdAt: now.addingTimeInterval(-172800),
                flashcards: []
            )
        ]
    }
}
