//
//  ProdQuizGenerationService.swift
//  Keyoku
//

import Foundation
import FoundationModels

@MainActor
final class ProdQuizGenerationService: QuizGenerationService {

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
        await router.tokenCount(for: GeneratedQuizBatch.generationSchema)
    }

    func streamQuizQuestions(prompt: String, instructions: String) -> AsyncThrowingStream<[GeneratedQuizQuestionDraft], Error> {
        let snapshots = router.stream(prompt: prompt, instructions: instructions, generating: GeneratedQuizBatch.self)
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: [GeneratedQuizQuestionDraft].self)

        let task = Task {
            do {
                for try await snapshot in snapshots {
                    // A draft keeps its position once its question has started, so its id stays stable.
                    let drafts = (snapshot.questions ?? []).compactMap { item -> GeneratedQuizQuestionDraft? in
                        guard let question = item.question else { return nil }
                        return GeneratedQuizQuestionDraft(
                            question: question,
                            correctAnswer: item.correctAnswer ?? "",
                            wrongAnswers: item.wrongAnswers ?? [],
                            explanation: item.explanation ?? ""
                        )
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

    func generateQuizTitle(prompt: String, instructions: String) async throws -> String {
        try await router.respondOnDevice(to: prompt, instructions: instructions, generating: GeneratedQuizTitle.self).title
    }
}
