//
//  FlashcardModel.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import Foundation
import IdentifiableByString

struct FlashcardModel: StringIdentifiable, Codable, Sendable {
    var id: String {
        flashcardId
    }

    let flashcardId: String
    let question: String
    let answer: String
    let deckId: String?
    let isLearned: Bool
    let repetitions: Int
    let interval: Int
    let easeFactor: Double
    let dueDate: Date?
    let stillLearningCount: Int

    init(
        flashcardId: String = UUID().uuidString,
        question: String,
        answer: String,
        deckId: String? = nil,
        isLearned: Bool = false,
        repetitions: Int = 0,
        interval: Int = 0,
        easeFactor: Double = 2.5,
        dueDate: Date? = nil,
        stillLearningCount: Int = 0
    ) {
        self.flashcardId = flashcardId
        self.question = question
        self.answer = answer
        self.deckId = deckId
        self.isLearned = isLearned
        self.repetitions = repetitions
        self.interval = interval
        self.easeFactor = easeFactor
        self.dueDate = dueDate
        self.stillLearningCount = stillLearningCount
    }

    init(entity: FlashcardEntity) {
        self.flashcardId = entity.id
        self.question = entity.question
        self.answer = entity.answer
        self.deckId = entity.deck?.id
        self.isLearned = entity.isLearned
        self.repetitions = entity.repetitions
        self.interval = entity.interval
        self.easeFactor = entity.easeFactor
        self.dueDate = entity.dueDate
        self.stillLearningCount = entity.stillLearningCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.flashcardId = try container.decode(String.self, forKey: .flashcardId)
        self.question = try container.decode(String.self, forKey: .question)
        self.answer = try container.decode(String.self, forKey: .answer)
        self.deckId = try container.decodeIfPresent(String.self, forKey: .deckId)
        self.isLearned = try container.decodeIfPresent(Bool.self, forKey: .isLearned) ?? false
        self.repetitions = try container.decodeIfPresent(Int.self, forKey: .repetitions) ?? 0
        self.interval = try container.decodeIfPresent(Int.self, forKey: .interval) ?? 0
        self.easeFactor = try container.decodeIfPresent(Double.self, forKey: .easeFactor) ?? 2.5
        self.dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        self.stillLearningCount = try container.decodeIfPresent(Int.self, forKey: .stillLearningCount) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case flashcardId = "flashcard_id"
        case question
        case answer
        case deckId = "deck_id"
        case isLearned = "is_learned"
        case repetitions
        case interval
        case easeFactor = "ease_factor"
        case dueDate = "due_date"
        case stillLearningCount = "still_learning_count"
    }

    var isDue: Bool {
        dueDate == nil || dueDate! <= Date()
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "flashcard_\(CodingKeys.flashcardId.rawValue)": flashcardId,
            "flashcard_\(CodingKeys.question.rawValue)": question,
            "flashcard_\(CodingKeys.answer.rawValue)": answer,
            "flashcard_\(CodingKeys.deckId.rawValue)": deckId,
            "flashcard_\(CodingKeys.isLearned.rawValue)": isLearned,
            "flashcard_\(CodingKeys.stillLearningCount.rawValue)": stillLearningCount
        ]
        return dict.compactMapValues({ $0 })
    }

    func toEntity() -> FlashcardEntity {
        FlashcardEntity(
            id: flashcardId,
            question: question,
            answer: answer,
            isLearned: isLearned,
            repetitions: repetitions,
            interval: interval,
            easeFactor: easeFactor,
            dueDate: dueDate,
            stillLearningCount: stillLearningCount
        )
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        let now = Date()
        let dayAgo = now.addingTimeInterval(-86400)
        let twoDaysAgo = now.addingTimeInterval(-172800)
        let threeDaysAgo = now.addingTimeInterval(-259200)
        return [
            // Deck 1 — Spanish Essentials
            // flashcard1–3: learned + overdue (appear in Review Due section)
            FlashcardModel(
                flashcardId: "flashcard1",
                question: "How do you say 'Good morning' in Spanish?",
                answer: "Buenos días. It's used as a greeting from sunrise until around noon, and is one of the most common everyday phrases in Spanish-speaking countries.",
                deckId: "deck1",
                isLearned: true,
                repetitions: 2,
                interval: 3,
                easeFactor: 2.5,
                dueDate: twoDaysAgo
            ),
            FlashcardModel(
                flashcardId: "flashcard2",
                question: "What is the difference between 'ser' and 'estar'?",
                answer: "Both mean 'to be,' but 'ser' is used for permanent traits like identity and origin, while 'estar' is used for temporary states like emotions and locations.",
                deckId: "deck1",
                isLearned: true,
                repetitions: 3,
                interval: 7,
                easeFactor: 2.6,
                dueDate: dayAgo
            ),
            FlashcardModel(
                flashcardId: "flashcard3",
                question: "How do you conjugate 'hablar' in present tense?",
                answer: "Yo hablo, tú hablas, él/ella habla, nosotros hablamos, vosotros habláis, ellos/ellas hablan. It follows the regular -ar verb pattern.",
                deckId: "deck1",
                isLearned: true,
                repetitions: 1,
                interval: 1,
                easeFactor: 2.3,
                dueDate: threeDaysAgo
            ),
            // flashcard4–6: still learning (appear in Still Learning section)
            FlashcardModel(
                flashcardId: "flashcard4",
                question: "What does '¿Cómo te llamas?' mean?",
                answer: "It means 'What is your name?' Literally translated it asks 'How do you call yourself?' The formal version is '¿Cómo se llama usted?'",
                deckId: "deck1",
                stillLearningCount: 4
            ),
            FlashcardModel(
                flashcardId: "flashcard5",
                question: "How do you order food at a restaurant in Spanish?",
                answer: "Use 'Me gustaría...' (I would like) or 'Quisiera...' (I'd like) followed by the item. For example: 'Me gustaría un café, por favor.'",
                deckId: "deck1",
                stillLearningCount: 2
            ),
            FlashcardModel(
                flashcardId: "flashcard6",
                question: "What are the four definite articles in Spanish?",
                answer: "El (masculine singular), la (feminine singular), los (masculine plural), and las (feminine plural). They correspond to 'the' in English.",
                deckId: "deck1",
                stillLearningCount: 1
            ),
            FlashcardModel(
                flashcardId: "flashcard7",
                question: "How do you express the future tense simply?",
                answer: "Use 'ir + a + infinitive.' For example: 'Voy a estudiar' means 'I am going to study.' This is the most common way to talk about future plans in everyday conversation.",
                deckId: "deck1"
            ),
            FlashcardModel(
                flashcardId: "flashcard8",
                question: "What is the difference between 'por' and 'para'?",
                answer: "'Por' expresses cause, duration, and exchange (por la mañana, gracias por). 'Para' expresses purpose, destination, and deadlines (para ti, para mañana).",
                deckId: "deck1"
            ),
            // Deck 2 — Biology 101
            // flashcard9: learned + overdue
            FlashcardModel(
                flashcardId: "flashcard9",
                question: "What is the powerhouse of the cell?",
                answer: "The mitochondria. They generate most of the cell's supply of adenosine triphosphate (ATP), which is used as a source of chemical energy to power cellular processes.",
                deckId: "deck2",
                isLearned: true,
                repetitions: 4,
                interval: 14,
                easeFactor: 2.8,
                dueDate: threeDaysAgo
            ),
            // flashcard10–12: still learning with varying attempt counts
            FlashcardModel(
                flashcardId: "flashcard10",
                question: "What is the difference between DNA and RNA?",
                answer: "DNA is double-stranded and uses deoxyribose sugar with thymine. RNA is single-stranded and uses ribose sugar with uracil. DNA stores genetic info; RNA helps express it.",
                deckId: "deck2",
                stillLearningCount: 7
            ),
            FlashcardModel(
                flashcardId: "flashcard11",
                question: "What are the stages of mitosis?",
                answer: "Prophase, metaphase, anaphase, and telophase (PMAT). During mitosis a single cell divides to produce two identical daughter cells with the same number of chromosomes.",
                deckId: "deck2",
                stillLearningCount: 3
            ),
            FlashcardModel(
                flashcardId: "flashcard12",
                question: "What is natural selection?",
                answer: "The process where organisms with favorable traits are more likely to survive and reproduce. Over generations, these traits become more common in the population, driving evolution.",
                deckId: "deck2"
            ),
            FlashcardModel(
                flashcardId: "flashcard13",
                question: "What is the function of ribosomes?",
                answer: "Ribosomes are the cellular structures responsible for protein synthesis. They read messenger RNA sequences and translate them into polypeptide chains that fold into functional proteins.",
                deckId: "deck2"
            ),
            FlashcardModel(
                flashcardId: "flashcard14",
                question: "What is homeostasis?",
                answer: "The ability of an organism to maintain stable internal conditions despite external changes. Examples include body temperature regulation, blood pH balance, and glucose levels.",
                deckId: "deck2"
            ),
            // Deck 3 — World History (all still learning, no due cards)
            FlashcardModel(
                flashcardId: "flashcard15",
                question: "What caused the fall of the Roman Empire?",
                answer: "A combination of military overspending, political instability, barbarian invasions, economic decline, and overreliance on slave labor weakened Rome over centuries until its fall in 476 AD.",
                deckId: "deck3",
                stillLearningCount: 5
            ),
            FlashcardModel(
                flashcardId: "flashcard16",
                question: "What was the significance of the printing press?",
                answer: "Invented by Gutenberg around 1440, it made books affordable and widely available, fueling the Renaissance, the Reformation, and the Scientific Revolution by democratizing knowledge.",
                deckId: "deck3",
                stillLearningCount: 2
            ),
            FlashcardModel(
                flashcardId: "flashcard17",
                question: "What were the main causes of World War I?",
                answer: "Militarism, alliances, imperialism, and nationalism (MAIN). The assassination of Archduke Franz Ferdinand in 1914 was the immediate trigger that set the alliance system into motion.",
                deckId: "deck3"
            ),
            FlashcardModel(
                flashcardId: "flashcard18",
                question: "What was the Cold War?",
                answer: "A geopolitical rivalry between the US and Soviet Union from 1947–1991. It featured an arms race, proxy wars, and ideological conflict between capitalism and communism, but no direct military confrontation.",
                deckId: "deck3"
            ),
            FlashcardModel(
                flashcardId: "flashcard19",
                question: "Why was the Silk Road historically important?",
                answer: "It was a network of trade routes connecting East and West from the 2nd century BC. It facilitated the exchange of goods like silk and spices, as well as ideas, religions, and technologies across civilizations.",
                deckId: "deck3"
            ),
            // Deck 4 — Python Basics (no due cards, no still learning — clean deck)
            FlashcardModel(
                flashcardId: "flashcard20",
                question: "What is the difference between a list and a tuple in Python?",
                answer: "Lists are mutable (can be changed after creation) and use square brackets []. Tuples are immutable (cannot be changed) and use parentheses (). Tuples are faster and can be used as dictionary keys.",
                deckId: "deck4"
            ),
            FlashcardModel(
                flashcardId: "flashcard21",
                question: "What does 'self' refer to in a Python class?",
                answer: "It refers to the current instance of the class. It allows access to the attributes and methods of the object. It must be the first parameter of instance methods, though Python passes it automatically.",
                deckId: "deck4"
            ),
            FlashcardModel(
                flashcardId: "flashcard22",
                question: "How does a dictionary work in Python?",
                answer: "A dictionary stores key-value pairs using curly braces {}. Keys must be unique and immutable. Access values with dict[key]. Common methods include .get(), .keys(), .values(), and .items().",
                deckId: "deck4"
            ),
            FlashcardModel(
                flashcardId: "flashcard23",
                question: "What is a list comprehension?",
                answer: "A concise way to create lists: [expression for item in iterable if condition]. For example, [x**2 for x in range(10) if x % 2 == 0] creates a list of squares of even numbers from 0 to 9.",
                deckId: "deck4"
            ),
            FlashcardModel(
                flashcardId: "flashcard24",
                question: "What is the difference between '==' and 'is' in Python?",
                answer: "'==' checks if two objects have the same value (equality). 'is' checks if two variables point to the exact same object in memory (identity). Use '==' for value comparison in most cases.",
                deckId: "deck4"
            )
        ]
    }
}
