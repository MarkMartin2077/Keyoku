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
    let clickCount: Int
    let lastStudiedAt: Date?

    init(
        deckId: String = UUID().uuidString,
        name: String,
        color: DeckColor = .blue,
        imageUrl: String? = nil,
        sourceText: String,
        createdAt: Date = .now,
        flashcards: [FlashcardModel] = [],
        clickCount: Int = 0,
        lastStudiedAt: Date? = nil
    ) {
        self.deckId = deckId
        self.name = name
        self.color = color
        self.imageUrl = imageUrl
        self.sourceText = sourceText
        self.createdAt = createdAt
        self.flashcards = flashcards
        self.clickCount = clickCount
        self.lastStudiedAt = lastStudiedAt
    }

    init(entity: DeckEntity) {
        self.deckId = entity.id
        self.name = entity.name
        self.color = entity.color
        self.imageUrl = entity.imageUrl
        self.sourceText = entity.sourceText
        self.createdAt = entity.createdAt
        self.flashcards = entity.flashcards.map { FlashcardModel(entity: $0) }
        self.clickCount = entity.clickCount
        self.lastStudiedAt = entity.lastStudiedAt
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
        case clickCount = "click_count"
        case lastStudiedAt = "last_studied_at"
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "deck_\(CodingKeys.deckId.rawValue)": deckId,
            "deck_\(CodingKeys.name.rawValue)": name,
            "deck_\(CodingKeys.color.rawValue)": color.rawValue,
            "deck_\(CodingKeys.imageUrl.rawValue)": imageUrl,
            "deck_\(CodingKeys.sourceText.rawValue)": sourceText,
            "deck_\(CodingKeys.createdAt.rawValue)": createdAt,
            "deck_flashcard_count": flashcards.count,
            "deck_\(CodingKeys.clickCount.rawValue)": clickCount,
            "deck_\(CodingKeys.lastStudiedAt.rawValue)": lastStudiedAt
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
        let entity = DeckEntity(id: deckId, name: name, color: color, imageUrl: imageUrl, sourceText: sourceText, createdAt: createdAt, clickCount: clickCount, lastStudiedAt: lastStudiedAt)
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

    /// Long enough (over 1,500 characters) that the mock Spanish deck can make quizzes.
    private static let spanishMockSourceText = """
    Core Spanish vocabulary, grammar, and conversational phrases for beginners.

    Greetings: "Hola" means hello and works at any time of day. "Buenos días" is good morning, \
    "buenas tardes" is good afternoon and "buenas noches" is good evening or good night. To say goodbye, \
    use "adiós", or "hasta luego" for see you later and "hasta mañana" for see you tomorrow.

    Courtesy: "Por favor" means please and "gracias" means thank you. The usual reply to thanks is \
    "de nada", meaning you're welcome. "Lo siento" is an apology, while "perdón" and "con permiso" \
    are used to get someone's attention or to ask to pass.

    The verbs ser and estar both mean "to be". Ser describes lasting traits such as identity, origin, \
    profession and personality: "Soy de México" (I am from Mexico). Estar describes temporary states \
    and locations: "Estoy cansado" (I am tired) and "El libro está en la mesa" (the book is on the table).

    Nouns have gender. Most nouns ending in -o are masculine and take "el", like "el libro". Most nouns \
    ending in -a are feminine and take "la", like "la mesa". Plurals add -s after a vowel and -es after \
    a consonant: "los libros", "las ciudades".

    Common questions: "¿Cómo estás?" asks how you are, "¿Cómo te llamas?" asks your name and \
    "¿De dónde eres?" asks where you are from. Answer with "Estoy bien", "Me llamo Ana" and "Soy de España". \
    Questions and exclamations open with inverted marks, ¿ and ¡, as well as closing with the usual ones.

    Numbers one to five are uno, dos, tres, cuatro and cinco. The days of the week are not capitalised \
    in Spanish: lunes, martes, miércoles, jueves, viernes, sábado and domingo.
    """

    static var mocks: [Self] {
        let now = Date()
        let allCards = FlashcardModel.mocks
        return [
            DeckModel(
                deckId: "deck1",
                name: "Spanish Essentials",
                color: .orange,
                sourceText: Self.spanishMockSourceText,
                createdAt: now,
                flashcards: allCards.filter { $0.deckId == "deck1" },
                clickCount: 5,
                lastStudiedAt: now.addingTimeInterval(-3600)
            ),
            DeckModel(
                deckId: "deck2",
                name: "Biology 101",
                color: .teal,
                sourceText: "Introductory biology covering cells, genetics, evolution, and homeostasis",
                createdAt: now.addingTimeInterval(-86400),
                flashcards: allCards.filter { $0.deckId == "deck2" },
                clickCount: 2
            ),
            DeckModel(
                deckId: "deck3",
                name: "World History",
                color: .indigo,
                sourceText: "Major historical events, causes, and their lasting impact on civilization",
                createdAt: now.addingTimeInterval(-172800),
                flashcards: allCards.filter { $0.deckId == "deck3" },
                clickCount: 8,
                lastStudiedAt: now.addingTimeInterval(-86400)
            ),
            DeckModel(
                deckId: "deck4",
                name: "Python Basics",
                color: .green,
                sourceText: "Python fundamentals including data types, classes, and common patterns",
                createdAt: now.addingTimeInterval(-259200),
                flashcards: allCards.filter { $0.deckId == "deck4" },
                clickCount: 0
            )
        ]
    }
}
