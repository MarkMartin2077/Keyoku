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

    init(
        flashcardId: String = UUID().uuidString,
        question: String,
        answer: String,
        deckId: String? = nil
    ) {
        self.flashcardId = flashcardId
        self.question = question
        self.answer = answer
        self.deckId = deckId
    }

    init(entity: FlashcardEntity) {
        self.flashcardId = entity.id
        self.question = entity.question
        self.answer = entity.answer
        self.deckId = entity.deck?.id
    }

    enum CodingKeys: String, CodingKey {
        case flashcardId = "flashcard_id"
        case question
        case answer
        case deckId = "deck_id"
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "flashcard_\(CodingKeys.flashcardId.rawValue)": flashcardId,
            "flashcard_\(CodingKeys.question.rawValue)": question,
            "flashcard_\(CodingKeys.answer.rawValue)": answer,
            "flashcard_\(CodingKeys.deckId.rawValue)": deckId
        ]
        return dict.compactMapValues({ $0 })
    }

    func toEntity() -> FlashcardEntity {
        FlashcardEntity(id: flashcardId, question: question, answer: answer)
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        [
            FlashcardModel(
                flashcardId: "flashcard1",
                question: "What is the capital of Japan?",
                answer: "Tokyo",
                deckId: "deck1"
            ),
            FlashcardModel(
                flashcardId: "flashcard2",
                question: "What does 'こんにちは' mean?",
                answer: "Hello",
                deckId: "deck1"
            ),
            FlashcardModel(
                flashcardId: "flashcard3",
                question: "How do you say 'Thank you' in Japanese?",
                answer: "ありgatou",
                deckId: "deck1"
            ),
            FlashcardModel(
                flashcardId: "flashcard4",
                question: "What is 1 + 1?",
                answer: "2",
                deckId: "deck2"
            )
        ]
    }
}
