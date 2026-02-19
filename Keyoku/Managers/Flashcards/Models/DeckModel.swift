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

    var displayImageUrlString: String? {
        guard let imageUrl else { return nil }
        if imageUrl.hasPrefix("http") {
            return imageUrl
        }
        return imageFileURL?.absoluteString
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
        let allCards = FlashcardModel.mocks
        return [
            DeckModel(
                deckId: "deck1",
                name: "Spanish Essentials",
                color: .orange,
                sourceText: "Core Spanish vocabulary, grammar, and conversational phrases for beginners",
                createdAt: now,
                flashcards: allCards.filter { $0.deckId == "deck1" }
            ),
            DeckModel(
                deckId: "deck2",
                name: "Biology 101",
                color: .teal,
                sourceText: "Introductory biology covering cells, genetics, evolution, and homeostasis",
                createdAt: now.addingTimeInterval(-86400),
                flashcards: allCards.filter { $0.deckId == "deck2" }
            ),
            DeckModel(
                deckId: "deck3",
                name: "World History",
                color: .indigo,
                sourceText: "Major historical events, causes, and their lasting impact on civilization",
                createdAt: now.addingTimeInterval(-172800),
                flashcards: allCards.filter { $0.deckId == "deck3" }
            ),
            DeckModel(
                deckId: "deck4",
                name: "Python Basics",
                color: .green,
                sourceText: "Python fundamentals including data types, classes, and common patterns",
                createdAt: now.addingTimeInterval(-259200),
                flashcards: allCards.filter { $0.deckId == "deck4" }
            )
        ]
    }
}
