//
//  FlashcardGenerationManagerTests.swift
//  KeyokuUnitTests
//

import Testing
import Foundation
@testable import Keyoku

private let studyText = [
    "Mitochondria produce ATP through cellular respiration, which powers most activity inside a cell.",
    "Ribosomes translate messenger RNA into chains of amino acids that fold into working proteins.",
    "The nucleus stores DNA and controls gene expression by regulating which genes are transcribed.",
    "Photosynthesis in chloroplasts converts light energy, water and carbon dioxide into glucose.",
    "The Treaty of Westphalia in 1648 ended the Thirty Years' War and shaped modern state sovereignty.",
    "Newton's second law states that force equals mass times acceleration for a constant mass.",
    "Supply and demand curves meet at an equilibrium price where buyers and sellers agree on quantity.",
    "Plate tectonics explains earthquakes and mountain ranges as rigid plates slide over the mantle.",
    "The Krebs cycle oxidizes acetyl groups and releases carbon dioxide as a waste product.",
    "Enzymes lower activation energy so reactions happen faster at body temperature.",
    "Osmosis moves water across a membrane from lower solute concentration to higher concentration.",
    "The Magna Carta of 1215 limited royal power and influenced later constitutional law."
].enumerated().map { index, sentence in
    "Section \(index + 1). \(sentence) Students often review this idea with worked examples and short quizzes."
}.joined(separator: "\n\n")

@Suite("FlashcardGenerationManager")
@MainActor
struct FlashcardGenerationManagerTests {

    private func makeManager(
        service: MockFlashcardGenerationService? = nil,
        mockLog: MockLogService? = nil
    ) -> (FlashcardGenerationManager, MockLogService) {
        let service = service ?? MockFlashcardGenerationService()
        let mockLog = mockLog ?? MockLogService()
        let manager = FlashcardGenerationManager(service: service, logManager: LogManager(services: [mockLog]))
        return (manager, mockLog)
    }

    private func collect(
        _ manager: FlashcardGenerationManager,
        text: String = studyText,
        count: Int,
        avoiding: [String] = []
    ) async -> (events: [GenerationEvent], failure: GenerationFailure?) {
        var events: [GenerationEvent] = []
        do {
            for try await event in manager.generateFlashcards(from: text, count: count, avoiding: avoiding) {
                events.append(event)
            }
            return (events, nil)
        } catch {
            return (events, error as? GenerationFailure)
        }
    }

    private func plannedBatchCount(_ events: [GenerationEvent]) -> Int? {
        guard case .started(_, let batchCount) = events.first else { return nil }
        return batchCount
    }

    private func finalCards(_ events: [GenerationEvent]) -> [FlashcardModel] {
        var state = GenerationProgressState()
        events.forEach { state.apply($0) }
        return state.cards
    }

    @Test("Starts, streams partials, completes every batch and tracks start and success")
    func eventOrder() async throws {
        let (manager, mockLog) = makeManager()

        let (events, failure) = await collect(manager, count: 10)

        #expect(failure == nil)
        guard case .started(let model, let batchCount) = try #require(events.first) else {
            Issue.record("First event should be .started")
            return
        }
        #expect(model == .onDevice)
        #expect(batchCount >= 4)
        let completed = events.compactMap { event -> Int? in
            if case .batchCompleted(let batch, _) = event { return batch }
            return nil
        }
        #expect(completed == Array(0..<batchCount))
        #expect(events.contains { if case .partial = $0 { return true } else { return false } })
        #expect(finalCards(events).count == 10)
        #expect(mockLog.hasEvent(named: "FlashcardGenMan_Generate_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardGenMan_Generate_Success"))
    }

    @Test("Filtered-out cards are topped up once, passing existing questions to avoid")
    func topUpAvoidingExistingQuestions() async {
        let service = MockFlashcardGenerationService()
        let (manager, _) = makeManager(service: service)
        let existing = ["What does sample concept 1 describe?", "WHAT does sample concept 2   describe?"]

        let (events, failure) = await collect(manager, count: 10, avoiding: existing)
        let questions = finalCards(events).map(\.question)

        #expect(failure == nil)
        #expect(questions.count == 10)
        #expect(!questions.contains("What does sample concept 1 describe?"))
        #expect(!questions.contains("What does sample concept 2 describe?"))
        #expect(service.prompts.count == plannedBatchCount(events).map { $0 + 1 })
        #expect(service.prompts.last?.contains("Generate exactly 2 flashcards") == true)
        #expect(service.prompts.last?.contains("Do NOT repeat or rephrase") == true)
    }

    @Test("Context overflow splits the batch in half and retries once")
    func contextOverflowSplits() async {
        let overflow = GenerationFailure.contextTooLarge
        let service = MockFlashcardGenerationService(failures: [0: overflow])
        let (manager, _) = makeManager(service: service)

        let (events, failure) = await collect(manager, count: 10)

        #expect(failure == nil)
        #expect(finalCards(events).count == 10)
        #expect(service.prompts.count == plannedBatchCount(events).map { $0 + 2 })
    }

    @Test("A rate-limited batch waits and retries once instead of skipping")
    func rateLimitRetries() async {
        let service = MockFlashcardGenerationService(failures: [0: GenerationFailure.rateLimited(retryAfter: .now)])
        let (manager, _) = makeManager(service: service)

        let (events, failure) = await collect(manager, count: 10)

        #expect(failure == nil)
        #expect(!events.contains { if case .batchSkipped = $0 { return true } else { return false } })
        #expect(finalCards(events).count == 10)
        #expect(service.prompts.count == plannedBatchCount(events).map { $0 + 1 })
    }

    @Test("Restricted batches are skipped with their reason; failures are tracked")
    func restrictedSkip() async {
        let service = MockFlashcardGenerationService(failures: [1: GenerationFailure.restricted])
        let (manager, mockLog) = makeManager(service: service)

        let (events, failure) = await collect(manager, count: 10)

        #expect(failure == nil)
        #expect(events.contains {
            if case .batchSkipped(1, .restricted) = $0 { return true } else { return false }
        })
        #expect(mockLog.hasEvent(named: "FlashcardGenMan_BatchSkipped"))
        #expect(finalCards(events).count == 10)
    }

    @Test("Unreadable text is skipped without calling the model and fails the run")
    func gibberishFails() async {
        let service = MockFlashcardGenerationService()
        let (manager, mockLog) = makeManager(service: service)
        let gibberish = String(repeating: "qwpoeiruty", count: 300)

        let (events, failure) = await collect(manager, text: gibberish, count: 10)

        #expect(failure == .unreadableText)
        #expect(service.prompts.isEmpty)
        #expect(events.contains { if case .batchSkipped(_, .unreadableText) = $0 { return true } else { return false } })
        #expect(mockLog.hasEvent(named: "FlashcardGenMan_Generate_Fail"))
    }

    @Test("Falling back from Private Cloud Compute announces the change and re-plans for the smaller window")
    func cloudFallback() async {
        let service = MockFlashcardGenerationService(availability: .available(.privateCloud), fallbackOnCall: 0)
        let (manager, mockLog) = makeManager(service: service)

        let (events, failure) = await collect(manager, count: 20)

        #expect(failure == nil)
        guard case .started(.privateCloud, let cloudBatches) = events.first else {
            Issue.record("Run should start on Private Cloud Compute")
            return
        }
        #expect(events.contains { if case .modelChanged(.onDevice) = $0 { return true } else { return false } })
        #expect(service.prompts.count > cloudBatches)
        #expect(finalCards(events).count == 20)
        #expect(mockLog.hasEvent(named: "FlashcardGenMan_ModelFallback"))
    }

    @Test("Unavailable models fail fast")
    func unavailable() async {
        let service = MockFlashcardGenerationService(availability: .unavailable(.appleIntelligenceNotEnabled))
        let (manager, _) = makeManager(service: service)

        let (events, failure) = await collect(manager, count: 10)

        #expect(events.isEmpty)
        #expect(failure == .modelUnavailable)
    }

    @Test("Cancelling the consumer stops generation and starts no new batches")
    func cancellation() async throws {
        let service = MockFlashcardGenerationService(delayPerCard: .milliseconds(20))
        let (manager, mockLog) = makeManager(service: service)

        let consumer = Task {
            var count = 0
            for try await event in manager.generateFlashcards(from: studyText, count: 10, avoiding: []) {
                count += 1
                if case .partial = event {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            }
            return count
        }
        _ = try? await consumer.value
        let promptsAtCancel = service.prompts.count
        try await Task.sleep(for: .milliseconds(300))

        #expect(promptsAtCancel == 1)
        #expect(service.prompts.count == promptsAtCancel)
        #expect(!mockLog.hasEvent(named: "FlashcardGenMan_Generate_Success"))
        #expect(mockLog.hasEvent(named: "FlashcardGenMan_Generate_Cancelled"))
    }

    @Test("PDF extraction failures are tracked")
    func pdfExtractFail() async {
        let (manager, mockLog) = makeManager()

        await #expect(throws: PDFExtractionError.self) {
            _ = try await manager.extractPDFText(from: URL(fileURLWithPath: "/nonexistent.pdf"))
        }
        #expect(mockLog.hasEvent(named: "FlashcardGenMan_PDFExtract_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardGenMan_PDFExtract_Fail"))
    }
}
