//
//  FlashcardGenerationStrategy.swift
//  Keyoku
//

import Foundation

/// Flashcards as a generation run's item: the flashcard prompt, card stream, quality filter and budget profile.
@MainActor
struct FlashcardGenerationStrategy: GenerationStrategy {

    private let service: FlashcardGenerationService
    private var filter: FlashcardQualityFilter

    init(service: FlashcardGenerationService, avoiding existingQuestions: [String]) {
        self.service = service
        self.filter = FlashcardQualityFilter(avoiding: existingQuestions)
    }

    var profile: GenerationProfile { .flashcards }

    var instructions: String { FlashcardPrompt.instructions }

    func prompt(count: Int, sourceText: String, avoiding existingQuestions: [String]) -> String {
        FlashcardPrompt.prompt(cardCount: count, sourceText: sourceText, avoiding: existingQuestions)
    }

    func schemaTokenCount() async -> Int {
        await service.schemaTokenCount()
    }

    func stream(prompt: String) -> AsyncThrowingStream<[GeneratedCardDraft], Error> {
        service.streamCards(prompt: prompt, instructions: instructions)
    }

    func item(from draft: GeneratedCardDraft, id: String) -> FlashcardModel {
        FlashcardModel(flashcardId: id, question: draft.question, answer: draft.answer)
    }

    func isComplete(_ item: FlashcardModel) -> Bool {
        FlashcardQualityFilter.isComplete(question: item.question, answer: item.answer)
    }

    func question(of item: FlashcardModel) -> String {
        item.question
    }

    mutating func accept(_ items: [FlashcardModel]) -> [FlashcardModel] {
        filter.accept(items)
    }
}
