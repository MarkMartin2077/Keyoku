//
//  GeneratedFlashcards.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import Foundation
import FoundationModels

// MARK: - Generation Types (Used only for AI generation step)

@Generable
struct GeneratedFlashcards {
    @Guide(
        description: "Generate educational flashcards based on the provided source text. " +
        "Each card should test a single concept with a clear, concise question and answer."
    )
    @Guide(.count(10))
    var cards: [GeneratedCard]
}

@Generable
struct GeneratedCard {
    @Guide(description: "A clear, specific question that tests understanding of a single concept")
    var question: String
    
    @Guide(description: "A concise, accurate answer to the question")
    var answer: String
}

// MARK: - Conversion to Domain Models

extension GeneratedFlashcards {
    
    func toModels(deckId: String? = nil) -> [FlashcardModel] {
        cards.map { $0.toModel(deckId: deckId) }
    }
    
    func toEntities() -> [FlashcardEntity] {
        cards.map { $0.toEntity() }
    }
}

extension GeneratedCard {
    
    func toModel(deckId: String? = nil) -> FlashcardModel {
        FlashcardModel(
            question: question,
            answer: answer,
            deckId: deckId
        )
    }
    
    func toEntity() -> FlashcardEntity {
        FlashcardEntity(
            question: question,
            answer: answer
        )
    }
}
