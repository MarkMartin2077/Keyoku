//
//  MockQuizGenerationService.swift
//  Keyoku
//

import Foundation

/// Streams canned quiz questions so Mock builds, previews and unit tests can exercise quiz generation.
@MainActor
final class MockQuizGenerationService: QuizGenerationService {

    var availability: GenerationAvailability
    /// Whether the title call's on-device model is available, whatever model the question calls use.
    var isOnDeviceAvailable: Bool
    private(set) var activeModel: GenerationModelKind
    private let contextSizes: [GenerationModelKind: Int]
    private let failures: [Int: any Error]
    private let delayPerQuestion: Duration
    private let makeDraft: (Int) -> GeneratedQuizQuestionDraft
    private let title: Result<String, any Error>

    private(set) var prompts: [String] = []
    private(set) var titlePrompts: [String] = []
    private var questionNumber = 0

    /// - Parameters:
    ///   - failures: Errors thrown by the question call at that index (0-based), before any question is streamed.
    ///   - makeDraft: Builds the nth streamed question (1-based, counted across calls). Defaults to valid, distinct questions.
    ///   - title: What the title call returns or throws.
    init(
        availability: GenerationAvailability = .available(.onDevice),
        isOnDeviceAvailable: Bool = true,
        contextSizes: [GenerationModelKind: Int] = [.onDevice: 4_096, .privateCloud: 32_768],
        failures: [Int: any Error] = [:],
        delayPerQuestion: Duration = .zero,
        makeDraft: @escaping (Int) -> GeneratedQuizQuestionDraft = MockQuizGenerationService.sampleDraft,
        title: Result<String, any Error> = .success("Sample Concepts")
    ) {
        self.availability = availability
        self.isOnDeviceAvailable = isOnDeviceAvailable
        if case .available(let model) = availability {
            self.activeModel = model
        } else {
            self.activeModel = .onDevice
        }
        self.contextSizes = contextSizes
        self.failures = failures
        self.delayPerQuestion = delayPerQuestion
        self.makeDraft = makeDraft
        self.title = title
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
        150
    }

    func streamQuizQuestions(prompt: String, instructions: String) -> AsyncThrowingStream<[GeneratedQuizQuestionDraft], Error> {
        let call = prompts.count
        prompts.append(prompt)

        let (stream, continuation) = AsyncThrowingStream.makeStream(of: [GeneratedQuizQuestionDraft].self)
        if let failure = failures[call] {
            continuation.finish(throwing: failure)
            return stream
        }

        let drafts = (0..<Self.requestedCount(in: prompt)).map { _ in
            questionNumber += 1
            return makeDraft(questionNumber)
        }
        let delay = delayPerQuestion

        let task = Task {
            do {
                for index in drafts.indices {
                    try await Task.sleep(for: delay)
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

    func generateQuizTitle(prompt: String, instructions: String) async throws -> String {
        titlePrompts.append(prompt)
        guard isOnDeviceAvailable else { throw GenerationFailure.modelUnavailable }
        return try title.get()
    }

    nonisolated static func sampleDraft(_ number: Int) -> GeneratedQuizQuestionDraft {
        GeneratedQuizQuestionDraft(
            question: "Which term names sample concept \(number)?",
            correctAnswer: "Concept \(number)",
            wrongAnswers: ["Idea \(number)", "Notion \(number)", "Theory \(number)"],
            explanation: "Sample concept \(number) is a canned question from the mock generation service."
        )
    }

    private static func requestedCount(in prompt: String) -> Int {
        guard let range = prompt.range(of: "exactly ") else { return 2 }
        return Int(prompt[range.upperBound...].prefix(while: \.isNumber)) ?? 2
    }
}
