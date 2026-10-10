//
//  GenerationLogicTests.swift
//  KeyokuUnitTests
//

import Testing
import Foundation
import FoundationModels
@testable import Keyoku

@Suite("FlashcardQualityFilter")
struct FlashcardQualityFilterTests {

    private func card(_ question: String, _ answer: String = "A complete answer sentence.") -> FlashcardModel {
        FlashcardModel(question: question, answer: answer)
    }

    @Test("Leak phrases match whole phrases only", arguments: [
        ("What does the textbook say about mitosis?", false),
        ("Which textile was traded most?", false),
        ("According to the text, what is mitosis?", true),
        ("What is described in the source text?", true),
        ("What does the text's author argue?", true)
    ])
    func leakPhrases(question: String, isLeak: Bool) {
        #expect(FlashcardQualityFilter.referencesSource(question) == isLeak)
    }

    @Test("Rejects short questions, short answers and answers that cite the text")
    func rejectsIncompleteCards() {
        var filter = FlashcardQualityFilter()

        let accepted = filter.accept([
            card("Why?", "Because cells divide."),
            card("What is mitosis?", "Division."),
            card("What is meiosis?", "As the text explains, it halves chromosomes."),
            card("What is ATP?", "The main energy currency of the cell.")
        ])

        #expect(accepted.map(\.question) == ["What is ATP?"])
    }

    @Test("Deduplicates across batches and against existing questions, ignoring case and spacing")
    func deduplicates() {
        var filter = FlashcardQualityFilter(avoiding: ["What is ATP?"])

        let first = filter.accept([card("what  is   atp?"), card("What is mitosis?")])
        let second = filter.accept([card("WHAT IS MITOSIS?"), card("What is meiosis?")])

        #expect(first.map(\.question) == ["What is mitosis?"])
        #expect(second.map(\.question) == ["What is meiosis?"])
    }
}

@Suite("GenerationErrorClassifier")
struct GenerationErrorClassifierTests {

    @Test("Context overflow maps to contextTooLarge")
    func contextSizeExceeded() {
        let error = LanguageModelError.contextSizeExceeded(.init(contextSize: 4_096, tokenCount: 5_000, debugDescription: "too big"))
        #expect(GenerationErrorClassifier.classify(error) == .contextTooLarge)
    }

    @Test("Rate limiting keeps the reset date")
    func rateLimited() {
        let resetDate = Date(timeIntervalSince1970: 1_000)
        let error = LanguageModelError.rateLimited(.init(resetDate: resetDate, debugDescription: "slow down"))
        #expect(GenerationErrorClassifier.classify(error) == .rateLimited(retryAfter: resetDate))
    }

    @Test("Guardrail violations are restricted, not failures")
    func guardrail() {
        let error = LanguageModelError.guardrailViolation(.init(debugDescription: "unsafe"))
        #expect(GenerationErrorClassifier.classify(error) == .restricted)
    }

    @Test("Private Cloud Compute errors are fallback-eligible", arguments: [
        PrivateCloudComputeLanguageModel.Error.networkFailure(.init(debugDescription: "offline")),
        .quotaLimitReached(.init(debugDescription: "quota")),
        .serviceUnavailable(.init(debugDescription: "down"))
    ])
    func cloudErrors(error: PrivateCloudComputeLanguageModel.Error) {
        #expect(GenerationErrorClassifier.classify(error) == .cloudUnavailable)
    }

    @Test("Cancellation, pass-through failures and unknown errors")
    func otherErrors() {
        #expect(GenerationErrorClassifier.classify(CancellationError()) == .cancelled)
        #expect(GenerationErrorClassifier.classify(GenerationFailure.unreadableText) == .unreadableText)
        if case .other = GenerationErrorClassifier.classify(URLError(.timedOut)) {
        } else {
            Issue.record("Unknown errors should classify as .other")
        }
    }
}

@Suite("GenerationProgressState")
struct GenerationProgressStateTests {

    private func cards(_ questions: String...) -> [FlashcardModel] {
        questions.map { FlashcardModel(question: $0, answer: "A complete answer sentence.") }
    }

    @Test("A partial replaces the batch's previous partial and completion replaces both")
    func partialsReplaced() {
        var state = GenerationProgressState()
        state.apply(.started(model: .onDevice, batchCount: 2))

        state.apply(.partial(batch: 0, cards: cards("Q1")))
        state.apply(.partial(batch: 0, cards: cards("Q1", "Q2")))
        #expect(state.previewCards.map(\.question) == ["Q1", "Q2"])
        #expect(state.cards.isEmpty)

        state.apply(.batchCompleted(batch: 0, cards: cards("Q1")))
        #expect(state.previewCards.map(\.question) == ["Q1"])
        #expect(state.cards.map(\.question) == ["Q1"])
        #expect(state.currentBatchNumber == 2)
    }

    @Test("A skipped batch discards its partial cards and is counted by reason")
    func skippedDropsPartials() {
        var state = GenerationProgressState()
        state.apply(.started(model: .onDevice, batchCount: 3))
        state.apply(.batchCompleted(batch: 0, cards: cards("Q1")))
        state.apply(.partial(batch: 1, cards: cards("Leaked partial")))

        state.apply(.batchSkipped(batch: 1, reason: .restricted))
        state.apply(.batchSkipped(batch: 2, reason: .unreadableText))

        #expect(state.previewCards.map(\.question) == ["Q1"])
        #expect(state.skippedCounts == [.restricted: 1, .unreadableText: 1])
        #expect(state.skippedSummary?.contains("unreadable text") == true)
        #expect(state.skippedSummary?.contains("content restrictions") == true)
    }

    @Test("A model change records the new model and drops the interrupted partial")
    func modelChange() {
        var state = GenerationProgressState()
        state.apply(.started(model: .privateCloud, batchCount: 1))
        state.apply(.partial(batch: 0, cards: cards("Q1")))

        state.apply(.modelChanged(.onDevice))

        #expect(state.model == .onDevice)
        #expect(state.previewCards.isEmpty)
    }

    @Test("Cards come out in batch order and a top-up batch extends the total")
    func orderingAndTopUp() {
        var state = GenerationProgressState()
        state.apply(.started(model: .onDevice, batchCount: 2))
        state.apply(.batchCompleted(batch: 1, cards: cards("B")))
        state.apply(.batchCompleted(batch: 0, cards: cards("A")))
        state.apply(.batchCompleted(batch: 2, cards: cards("C")))

        #expect(state.cards.map(\.question) == ["A", "B", "C"])
        #expect(state.totalBatchCount == 3)
        #expect(state.skippedSummary == nil)
    }
}
