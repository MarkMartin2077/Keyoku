//
//  BatchPlannerTests.swift
//  KeyokuUnitTests
//

import Testing
@testable import Keyoku

@Suite("GenerationBudget")
struct GenerationBudgetTests {

    @Test("A 4K window keeps today's 3 cards per call; bigger windows get bigger batches")
    func cardsPerBatchScalesWithWindow() {
        let small = GenerationBudget(contextSize: 4_096, overheadTokens: 650, tokensPerCharacter: 0.25)
        let medium = GenerationBudget(contextSize: 8_192, overheadTokens: 650, tokensPerCharacter: 0.25)
        let large = GenerationBudget(contextSize: 32_768, overheadTokens: 650, tokensPerCharacter: 0.25)

        #expect(small.cardsPerBatch == 3)
        #expect(medium.cardsPerBatch == 7)
        #expect(large.cardsPerBatch == 10)
        #expect(small.sourceTokens < medium.sourceTokens)
        #expect(medium.sourceTokens < large.sourceTokens)
    }

    @Test("Source, overhead and reserved output fit inside the window")
    func budgetFitsWindow() {
        let budget = GenerationBudget(contextSize: 4_096, overheadTokens: 650, tokensPerCharacter: 0.25)

        let used = 650 + budget.sourceTokens + budget.cardsPerBatch * GenerationBudget.outputTokensPerCard
        #expect(used <= 4_096)
        #expect(budget.sourceCharacters == Int(Double(budget.sourceTokens) / 0.25))
    }
}

@Suite("BatchPlanner")
struct BatchPlannerTests {

    private let budget = GenerationBudget(contextSize: 4_096, overheadTokens: 650, tokensPerCharacter: 0.25)

    private func paragraphs(_ count: Int, length: Int = 400) -> String {
        (0..<count).map { index in
            "Paragraph \(index). " + String(repeating: "Cells divide by mitosis and meiosis. ", count: length / 37)
        }.joined(separator: "\n\n")
    }

    @Test("A long document is covered end to end when every chunk gets cards")
    func coversWholeText() {
        let text = paragraphs(120)
        let batches = BatchPlanner.plan(text: text, cardCount: 50, budget: budget)

        #expect(batches.map(\.text).joined() == text)
        #expect(batches.map(\.index) == Array(0..<batches.count))
    }

    @Test("Card counts sum to the request and respect the per-batch cap", arguments: [1, 7, 10, 23, 50])
    func distributionSumsToCount(cardCount: Int) {
        let batches = BatchPlanner.plan(text: paragraphs(120), cardCount: cardCount, budget: budget)

        #expect(batches.map(\.cardCount).reduce(0, +) == cardCount)
        #expect(batches.allSatisfy { $0.cardCount > 0 && $0.cardCount <= budget.cardsPerBatch })
    }

    @Test("No chunk is longer than the source budget")
    func chunksFitBudget() {
        let batches = BatchPlanner.plan(text: paragraphs(200), cardCount: 50, budget: budget)

        #expect(batches.allSatisfy { $0.text.count <= budget.sourceCharacters })
    }

    @Test("Few cards over many chunks are spread across the document, not taken from the start")
    func fewCardsSpreadAcrossDocument() throws {
        let text = paragraphs(300)
        let batches = BatchPlanner.plan(text: text, cardCount: 4, budget: budget)
        let lastBatch = try #require(batches.last)
        let lastStart = try #require(text.range(of: lastBatch.text)).lowerBound

        #expect(batches.count == 4)
        #expect(batches.map(\.cardCount) == [1, 1, 1, 1])
        #expect(text.distance(from: text.startIndex, to: lastStart) > text.count * 3 / 4)
    }

    @Test("Chunks end on paragraph boundaries when paragraphs are available")
    func cutsAtParagraphBoundaries() {
        let batches = BatchPlanner.plan(text: paragraphs(120), cardCount: 50, budget: budget)

        #expect(batches.count > 1)
        #expect(batches.dropLast().allSatisfy { $0.text.hasSuffix("\n\n") })
    }

    @Test("Short text still gets enough batches for the requested cards")
    func smallTextSplitsForCardCount() {
        let text = paragraphs(4, length: 100)
        let batches = BatchPlanner.plan(text: text, cardCount: 10, budget: budget)

        #expect(batches.count == 4)
        #expect(batches.map(\.cardCount).reduce(0, +) == 10)
        #expect(batches.map(\.text).joined() == text)
    }

    @Test("Empty text or zero cards plans nothing")
    func emptyInputs() {
        #expect(BatchPlanner.plan(text: "", cardCount: 10, budget: budget).isEmpty)
        #expect(BatchPlanner.plan(text: paragraphs(2), cardCount: 0, budget: budget).isEmpty)
    }

    @Test("Proportional shares spread leftover cards instead of front-loading them")
    func distributeSpreadsLeftovers() {
        #expect(BatchPlanner.distribute(2, weights: [1, 1, 1, 1], cap: 3) == [1, 0, 1, 0])
        #expect(BatchPlanner.distribute(10, weights: [100, 300], cap: 10) == [3, 7])
        #expect(BatchPlanner.distribute(6, weights: [10, 1, 1], cap: 3) == [3, 2, 1])
    }

    @Test("Splitting in half keeps the batch index and the card count")
    func splitInHalf() {
        let batch = GenerationBatch(index: 4, text: paragraphs(4), cardCount: 5)
        let halves = BatchPlanner.splitInHalf(batch)

        #expect(halves.map(\.index) == [4, 4])
        #expect(halves.map(\.cardCount) == [3, 2])
        #expect(halves.map(\.text).joined() == batch.text)
    }
}
