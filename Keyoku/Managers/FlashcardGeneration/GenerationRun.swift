//
//  GenerationRun.swift
//  Keyoku
//

import Foundation

/// Everything a generation run needs to know about the item it generates.
/// The run owns budgeting, chunking, retries, model fallback and the top-up; a strategy owns the item.
@MainActor
protocol GenerationStrategy {
    /// One item as streamed by the model. While streaming, its fields may still be growing.
    associatedtype Draft: Sendable
    associatedtype Item

    var profile: GenerationProfile { get }
    var instructions: String { get }

    func prompt(count: Int, sourceText: String, avoiding existingQuestions: [String]) -> String

    /// Tokens the item's response schema adds to each call.
    func schemaTokenCount() async -> Int

    /// Each element is every draft generated so far in this call, not a delta.
    func stream(prompt: String) -> AsyncThrowingStream<[Draft], Error>

    /// `id` stays the same for a draft's position across snapshots of one call.
    func item(from draft: Draft, id: String) -> Item

    /// Whether a streamed item is finished enough to preview.
    func isComplete(_ item: Item) -> Bool

    /// The text later calls are told not to repeat.
    func question(of item: Item) -> String

    /// Returns the items worth keeping, in order, and remembers them so later batches can't repeat them.
    mutating func accept(_ items: [Item]) -> [Item]
}

enum GenerationRunEvent<Item> {
    case started(model: GenerationModelKind, batchCount: Int)
    case modelChanged(from: GenerationModelKind, to: GenerationModelKind)
    case partial(batch: Int, items: [Item])
    case batchCompleted(batch: Int, items: [Item])
    case batchSkipped(batch: Int, reason: SkipReason, failure: GenerationFailure?)
}

struct GenerationRunSummary {
    let requestedCount: Int
    let generatedCount: Int
    let batchCount: Int
    let skippedCount: Int
    let itemsPerBatch: Int
    let contextSize: Int
    let model: GenerationModelKind
}

/// One generation run. Owns the plan, the dedup state and the model the plan was budgeted for.
@MainActor
final class GenerationRun<Strategy: GenerationStrategy> {

    private enum BatchOutcome {
        case completed
        case skipped
        /// The model changed mid-batch; the batch must be re-planned for the new budget.
        case interrupted
    }

    private let text: String
    private let itemCount: Int
    private let existingQuestions: [String]
    private let service: any GenerationModelService
    private let emit: (GenerationRunEvent<Strategy.Item>) -> Void

    private var strategy: Strategy
    private var announcedModel: GenerationModelKind = .onDevice
    private var budgetModel: GenerationModelKind = .onDevice
    private var budget = GenerationBudget(contextSize: 0, overheadTokens: 0, tokensPerCharacter: 0)
    private var contextSize = 0
    private var overheadTokens = 0
    private var tokensPerCharacter = 0.0
    private var nextIndex = 0
    private var plannedBatches: [GenerationBatch] = []
    private var acceptedQuestions: [String] = []
    private var completedBatchCount = 0
    private var skippedBatchCount = 0
    private var restrictedSkipCount = 0
    private var lastFailure: GenerationFailure?

    /// `existingQuestions` feed the top-up's avoid list; the strategy should already reject them.
    init(
        text: String,
        itemCount: Int,
        existingQuestions: [String],
        service: any GenerationModelService,
        strategy: Strategy,
        emit: @escaping (GenerationRunEvent<Strategy.Item>) -> Void
    ) {
        self.text = text
        self.itemCount = itemCount
        self.existingQuestions = existingQuestions
        self.service = service
        self.strategy = strategy
        self.emit = emit
    }

    func run() async throws -> GenerationRunSummary {
        guard case .available = service.availability else {
            throw GenerationFailure.modelUnavailable
        }

        announcedModel = service.beginRun()
        budgetModel = announcedModel
        tokensPerCharacter = Double(await service.tokenCount(text)) / Double(max(text.count, 1))
        let template = strategy.prompt(count: strategy.profile.itemsPerCallCeiling, sourceText: "", avoiding: [])
        overheadTokens = await service.tokenCount(strategy.instructions)
            + service.tokenCount(template)
            + strategy.schemaTokenCount()
        await measureBudget()

        var pending = plan(text, itemCount: itemCount)
        emit(.started(model: announcedModel, batchCount: pending.count))

        while !pending.isEmpty {
            try Task.checkCancellation()
            let batch = pending.removeFirst()
            let outcome = try await process(batch)

            if service.activeModel != budgetModel {
                announceModelChangeIfNeeded()
                budgetModel = service.activeModel
                await measureBudget()
                let remaining = (outcome == .interrupted ? [batch] : []) + pending
                pending = plan(remaining.map(\.text).joined(), itemCount: remaining.map(\.cardCount).reduce(0, +))
            }
        }

        try await topUpIfShort()

        guard !acceptedQuestions.isEmpty else {
            throw lastFailure ?? (restrictedSkipCount > 0 ? .restricted : .unreadableText)
        }

        return GenerationRunSummary(
            requestedCount: itemCount,
            generatedCount: acceptedQuestions.count,
            batchCount: completedBatchCount + skippedBatchCount,
            skippedCount: skippedBatchCount,
            itemsPerBatch: budget.cardsPerBatch,
            contextSize: contextSize,
            model: announcedModel
        )
    }

    // MARK: Planning

    private func measureBudget() async {
        contextSize = await service.contextSize()
        budget = GenerationBudget(
            contextSize: contextSize,
            overheadTokens: overheadTokens,
            tokensPerCharacter: tokensPerCharacter,
            profile: strategy.profile
        )
    }

    private func plan(_ text: String, itemCount: Int) -> [GenerationBatch] {
        let batches = BatchPlanner.plan(text: text, cardCount: itemCount, budget: budget, firstIndex: nextIndex)
        nextIndex += batches.count
        plannedBatches += batches
        return batches
    }

    /// One extra batch on the largest chunk when filtering or skips left the run short of the requested count.
    private func topUpIfShort() async throws {
        let shortfall = itemCount - acceptedQuestions.count
        guard shortfall > 0, completedBatchCount > 0,
              let largest = plannedBatches.max(by: { $0.text.count < $1.text.count })
        else { return }
        try Task.checkCancellation()

        // The avoid list shares the source budget, so the largest chunk gives up room for it.
        let avoidBudgetCharacters = budget.sourceCharacters / 3
        var avoiding: [String] = []
        var avoidCharacters = 0
        for question in (existingQuestions + acceptedQuestions).reversed() {
            guard avoidCharacters + question.count <= avoidBudgetCharacters else { break }
            avoiding.append(question)
            avoidCharacters += question.count
        }
        let sourceLimit = budget.sourceCharacters - avoidCharacters
        let source = largest.text.count <= sourceLimit
            ? largest.text
            : String(largest.text[..<BatchPlanner.findBreak(
                in: largest.text,
                before: largest.text.index(largest.text.startIndex, offsetBy: sourceLimit),
                from: largest.text.startIndex
            )])

        let batch = GenerationBatch(index: nextIndex, text: source, cardCount: min(shortfall, budget.cardsPerBatch))
        nextIndex += 1
        if try await process(batch, avoiding: Array(avoiding.reversed())) == .interrupted {
            announceModelChangeIfNeeded()
            skip(batch.index, reason: .failed)
        }
    }

    // MARK: Batches

    private func process(_ batch: GenerationBatch, avoiding: [String] = []) async throws -> BatchOutcome {
        if looksLikeGibberish(batch.text) {
            skip(batch.index, reason: .unreadableText)
            return .skipped
        }

        var pieces = [batch]
        var hasRetried = false
        while true {
            do {
                let items = try await generate(pieces, index: batch.index, avoiding: avoiding)
                let accepted = strategy.accept(items)
                acceptedQuestions += accepted.map(strategy.question)
                completedBatchCount += 1
                emit(.batchCompleted(batch: batch.index, items: accepted))
                return .completed
            } catch {
                let failure = GenerationErrorClassifier.classify(error)
                if failure == .cancelled || Task.isCancelled {
                    throw CancellationError()
                }
                if service.activeModel != budgetModel {
                    return .interrupted
                }
                if !hasRetried, let retryPieces = try await retryPieces(for: failure, pieces: pieces) {
                    pieces = retryPieces
                    hasRetried = true
                    continue
                }
                skip(batch.index, reason: skipReason(for: failure))
                return .skipped
            }
        }
    }

    /// The pieces to retry once with, or nil when the failure isn't worth retrying.
    private func retryPieces(for failure: GenerationFailure, pieces: [GenerationBatch]) async throws -> [GenerationBatch]? {
        switch failure {
        case .contextTooLarge:
            return pieces.flatMap(BatchPlanner.splitInHalf)
        case .rateLimited(let retryAfter):
            let wait = min(max(retryAfter?.timeIntervalSinceNow ?? 5, 0), 5)
            try await Task.sleep(for: .seconds(wait))
            return pieces
        case .cloudUnavailable:
            return pieces
        default:
            return nil
        }
    }

    /// Streams the pieces of one batch in order. Partial events carry every item the batch has so far.
    private func generate(_ pieces: [GenerationBatch], index: Int, avoiding: [String]) async throws -> [Strategy.Item] {
        var committed: [Strategy.Item] = []
        for piece in pieces {
            var ids: [String] = []
            var latest: [Strategy.Item] = []
            let prompt = strategy.prompt(count: piece.cardCount, sourceText: piece.text, avoiding: avoiding)

            for try await drafts in strategy.stream(prompt: prompt) {
                announceModelChangeIfNeeded()
                let capped = drafts.prefix(piece.cardCount)
                while ids.count < capped.count {
                    ids.append(UUID().uuidString)
                }
                latest = zip(ids, capped).map { id, draft in
                    strategy.item(from: draft, id: id)
                }
                let preview = latest.filter(strategy.isComplete)
                emit(.partial(batch: index, items: committed + preview))
            }
            // A cancelled consumer ends the stream without throwing; don't treat that as a finished batch.
            try Task.checkCancellation()
            committed += latest
        }
        return committed
    }

    private func skipReason(for failure: GenerationFailure) -> SkipReason {
        switch failure {
        case .restricted:
            return .restricted
        case .unreadableText:
            return .unreadableText
        default:
            lastFailure = failure
            return .failed
        }
    }

    private func skip(_ index: Int, reason: SkipReason) {
        skippedBatchCount += 1
        if reason == .restricted {
            restrictedSkipCount += 1
        }
        emit(.batchSkipped(batch: index, reason: reason, failure: lastFailure))
    }

    private func announceModelChangeIfNeeded() {
        let model = service.activeModel
        guard model != announcedModel else { return }
        emit(.modelChanged(from: announcedModel, to: model))
        announcedModel = model
    }
}
