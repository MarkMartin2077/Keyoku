//
//  QuizGenerationStrategy.swift
//  Keyoku
//

import Foundation

/// Quiz questions as a generation run's item: the quiz prompt, question stream, quality filter and budget profile.
@MainActor
struct QuizGenerationStrategy: GenerationStrategy {

    private let service: QuizGenerationService
    private var filter: QuizQualityFilter

    init(service: QuizGenerationService, avoiding existingQuestions: [String]) {
        self.service = service
        self.filter = QuizQualityFilter(avoiding: existingQuestions)
    }

    var profile: GenerationProfile { .quiz }

    var instructions: String { QuizPrompt.instructions }

    /// A new quiz should feel fresh, so every call is told about the deck's other quizzes.
    var avoidsExistingQuestionsInEveryCall: Bool { true }

    func prompt(count: Int, sourceText: String, avoiding existingQuestions: [String]) -> String {
        QuizPrompt.prompt(questionCount: count, sourceText: sourceText, avoiding: existingQuestions)
    }

    func schemaTokenCount() async -> Int {
        await service.schemaTokenCount()
    }

    func stream(prompt: String) -> AsyncThrowingStream<[GeneratedQuizQuestionDraft], Error> {
        service.streamQuizQuestions(prompt: prompt, instructions: instructions)
    }

    func item(from draft: GeneratedQuizQuestionDraft, id: String) -> QuizQuestionModel {
        QuizQuestionModel(
            id: id,
            question: draft.question,
            correctAnswer: draft.correctAnswer,
            wrongAnswers: draft.wrongAnswers,
            explanation: draft.explanation
        )
    }

    func isComplete(_ item: QuizQuestionModel) -> Bool {
        QuizQualityFilter.isComplete(item)
    }

    func question(of item: QuizQuestionModel) -> String {
        item.question
    }

    mutating func accept(_ items: [QuizQuestionModel]) -> [QuizQuestionModel] {
        filter.accept(items)
    }
}
