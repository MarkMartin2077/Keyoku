//
//  ProdFlashcardGenerationService.swift
//  Keyoku
//

import Foundation
import FoundationModels

@MainActor
final class ProdFlashcardGenerationService: FlashcardGenerationService {

    private let router = LanguageModelRouter()

    var availability: GenerationAvailability { router.availability }

    var activeModel: GenerationModelKind { router.activeModel }

    func beginRun() -> GenerationModelKind {
        router.beginRun()
    }

    func prewarm(instructions: String) {
        router.prewarm(instructions: instructions)
    }

    func contextSize() async -> Int {
        await router.contextSize()
    }

    func tokenCount(_ text: String) async -> Int {
        await router.tokenCount(text)
    }

    func schemaTokenCount() async -> Int {
        await router.tokenCount(for: GeneratedFlashcardBatch.generationSchema)
    }

    func streamCards(prompt: String, instructions: String) -> AsyncThrowingStream<[GeneratedCardDraft], Error> {
        let snapshots = router.stream(prompt: prompt, instructions: instructions, generating: GeneratedFlashcardBatch.self)
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: [GeneratedCardDraft].self)

        let task = Task {
            do {
                for try await snapshot in snapshots {
                    let drafts = (snapshot.cards ?? []).compactMap { card -> GeneratedCardDraft? in
                        guard let question = card.question, let answer = card.answer else { return nil }
                        return GeneratedCardDraft(question: question, answer: answer)
                    }
                    continuation.yield(drafts)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }
}
