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

@Generable
struct GeneratedMCQuestion {
    @Guide(description: "The question text")
    let questionText: String
    @Guide(description: "First answer option")
    let optionOne: String
    @Guide(description: "Second answer option")
    let optionTwo: String
    @Guide(description: "Third answer option")
    let optionThree: String
    @Guide(description: "Fourth answer option")
    let optionFour: String
    @Guide(description: "Index of the correct option (0-3)")
    let correctOptionIndex: Int
}

@Generable
struct GeneratedMCBatch {
    @Guide(description: "Array of generated multiple choice questions")
    let questions: [GeneratedMCQuestion]
}

@Generable
struct GeneratedTFStatement {
    @Guide(description: "A true or false statement")
    let statement: String
    @Guide(description: "Whether the statement is true")
    let isTrue: Bool
}

@Generable
struct GeneratedTFBatch {
    @Guide(description: "Array of generated true/false statements")
    let statements: [GeneratedTFStatement]
}

@Generable
struct TopicCheckResult {
    @Guide(description: "The main topic of the text")
    let topic: String
}
