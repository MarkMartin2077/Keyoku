//
//  GenerationModels.swift
//  Keyoku
//
//  Created by Mark Martin on 2/16/26.
//

import FoundationModels

@Generable
struct GeneratedFlashcard {
    @Guide(description: "The flashcard question")
    let question: String
    @Guide(description: "The flashcard answer")
    let answer: String
}

@Generable
struct GeneratedFlashcardBatch {
    @Guide(description: "Array of generated flashcards")
    let cards: [GeneratedFlashcard]
}

