//
//  FlashcardGenerationService.swift
//  Keyoku
//

import Foundation

/// One card as streamed by the model. While streaming, `answer` may still be growing.
struct GeneratedCardDraft: Equatable, Sendable {
    let question: String
    let answer: String
}

@MainActor
protocol FlashcardGenerationService: Sendable {
    var availability: GenerationAvailability { get }

    /// The model the current run is using. Moves to `.onDevice` when Private Cloud Compute falls back mid-run.
    var activeModel: GenerationModelKind { get }

    /// Picks the preferred available model for a new run and returns it.
    func beginRun() -> GenerationModelKind

    func prewarm(instructions: String)

    /// Context window of the active model, in tokens.
    func contextSize() async -> Int

    func tokenCount(_ text: String) async -> Int

    /// Tokens the flashcard response schema adds to each call.
    func schemaTokenCount() async -> Int

    /// Each element is every card generated so far in this call, not a delta.
    func streamCards(prompt: String, instructions: String) -> AsyncThrowingStream<[GeneratedCardDraft], Error>
}
