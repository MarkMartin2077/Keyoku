//
//  MockFlashcardGenerationService.swift
//  Keyoku
//

import Foundation

/// Streams canned cards so Mock builds, previews, UI tests and unit tests can exercise generation.
@MainActor
final class MockFlashcardGenerationService: FlashcardGenerationService {

    var availability: GenerationAvailability
    private(set) var activeModel: GenerationModelKind
    private let contextSizes: [GenerationModelKind: Int]
    private let failures: [Int: any Error]
    private let fallbackOnCall: Int?
    private let delayPerCard: Duration

    private(set) var prompts: [String] = []
    private var cardNumber = 0

    /// - Parameters:
    ///   - failures: Errors thrown by the call at that index (0-based), before any card is streamed.
    ///   - fallbackOnCall: The call at that index switches a Private Cloud Compute run to on-device first.
    init(
        availability: GenerationAvailability = .available(.onDevice),
        contextSizes: [GenerationModelKind: Int] = [.onDevice: 4_096, .privateCloud: 32_768],
        failures: [Int: any Error] = [:],
        fallbackOnCall: Int? = nil,
        delayPerCard: Duration = .zero
    ) {
        self.availability = availability
        if case .available(let model) = availability {
            self.activeModel = model
        } else {
            self.activeModel = .onDevice
        }
        self.contextSizes = contextSizes
        self.failures = failures
        self.fallbackOnCall = fallbackOnCall
        self.delayPerCard = delayPerCard
    }

    func beginRun() -> GenerationModelKind {
        if case .available(let model) = availability {
            activeModel = model
        }
        return activeModel
    }

    func prewarm(instructions: String) { }

    func contextSize() async -> Int {
        contextSizes[activeModel] ?? 4_096
    }

    func tokenCount(_ text: String) async -> Int {
        max(text.count / 4, 1)
    }

    func schemaTokenCount() async -> Int {
        100
    }

    func streamCards(prompt: String, instructions: String) -> AsyncThrowingStream<[GeneratedCardDraft], Error> {
        let call = prompts.count
        prompts.append(prompt)
        if call == fallbackOnCall {
            activeModel = .onDevice
        }

        let (stream, continuation) = AsyncThrowingStream.makeStream(of: [GeneratedCardDraft].self)
        if let failure = failures[call] {
            continuation.finish(throwing: failure)
            return stream
        }

        let drafts = (0..<Self.requestedCardCount(in: prompt)).map { _ in nextDraft() }

        let task = Task {
            do {
                for index in drafts.indices {
                    try await Task.sleep(for: delayPerCard)
                    continuation.yield(Array(drafts[...index]))
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    private func nextDraft() -> GeneratedCardDraft {
        cardNumber += 1
        return GeneratedCardDraft(
            question: "What does sample concept \(cardNumber) describe?",
            answer: "Sample concept \(cardNumber) is a canned answer from the mock generation service."
        )
    }

    private static func requestedCardCount(in prompt: String) -> Int {
        guard let range = prompt.range(of: "exactly ") else { return 3 }
        return Int(prompt[range.upperBound...].prefix(while: \.isNumber)) ?? 3
    }
}
