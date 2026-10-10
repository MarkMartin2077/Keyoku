//
//  QuizGenerationSchema.swift
//  Keyoku
//

import FoundationModels

/// Properties are generated in declaration order: the model commits to the correct answer
/// before writing wrong answers that differ from it, and explains last.
@Generable
struct GeneratedQuizQuestion {
    @Guide(description: "The question")
    let question: String
    @Guide(description: "The one correct answer")
    let correctAnswer: String
    @Guide(description: "Three plausible wrong answers", .count(QuizQualityFilter.wrongAnswerCount))
    let wrongAnswers: [String]
    @Guide(description: "One sentence explaining the correct answer")
    let explanation: String
}

@Generable
struct GeneratedQuizBatch {
    @Guide(description: "Array of quiz questions", .maximumCount(GenerationProfile.quiz.itemsPerCallCeiling))
    let questions: [GeneratedQuizQuestion]
}

@Generable
struct GeneratedQuizTitle {
    @Guide(description: "A quiz title of at most six words")
    let title: String
}
