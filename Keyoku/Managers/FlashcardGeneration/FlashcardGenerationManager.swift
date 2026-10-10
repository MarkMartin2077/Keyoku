//
//  FlashcardGenerationManager.swift
//  Keyoku
//

import Foundation

/// Generates flashcards from study text and extracts text from PDFs.
///
/// A run measures the active model's context window, plans token-budgeted batches over the whole text,
/// streams each batch, filters and deduplicates the results, and tops up once if filtering left it short.
/// Progress is reported as `GenerationEvent`s; the stream finishes with a `GenerationFailure` only when
/// no cards at all could be generated.
@MainActor
@Observable
final class FlashcardGenerationManager {

    private let service: FlashcardGenerationService
    private let logManager: LogManager?

    init(service: FlashcardGenerationService, logManager: LogManager? = nil) {
        self.service = service
        self.logManager = logManager
    }

    var generationAvailability: GenerationAvailability {
        service.availability
    }

    func prewarmGeneration() {
        logManager?.trackEvent(event: Event.prewarm)
        service.prewarm(instructions: FlashcardPrompt.instructions)
    }

    func generateFlashcards(
        from text: String,
        count: Int,
        avoiding existingQuestions: [String]
    ) -> AsyncThrowingStream<GenerationEvent, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: GenerationEvent.self)
        let run = GenerationRun(
            text: text,
            cardCount: count,
            existingQuestions: existingQuestions,
            service: service,
            logManager: logManager,
            emit: { continuation.yield($0) }
        )

        let task = Task {
            logManager?.trackEvent(event: Event.generateStart(textLength: text.count, cardCount: count, avoidingCount: existingQuestions.count))
            do {
                let summary = try await run.run()
                logManager?.trackEvent(event: Event.generateSuccess(summary: summary))
                continuation.finish()
            } catch {
                let failure = GenerationErrorClassifier.classify(error)
                if failure == .cancelled {
                    logManager?.trackEvent(event: Event.generateCancelled)
                } else {
                    logManager?.trackEvent(event: Event.generateFail(failure: failure))
                }
                continuation.finish(throwing: failure)
            }
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func extractPDFText(from url: URL) async throws -> (text: String, pageCount: Int) {
        logManager?.trackEvent(event: Event.pdfExtractStart)
        do {
            let result = try await PDFTextExtractor.extractText(from: url)
            logManager?.trackEvent(event: Event.pdfExtractSuccess(pageCount: result.pageCount, textLength: result.text.count))
            return result
        } catch {
            logManager?.trackEvent(event: Event.pdfExtractFail(error: error))
            throw error
        }
    }
}

// MARK: - Run

struct GenerationRunSummary {
    let requestedCount: Int
    let generatedCount: Int
    let batchCount: Int
    let skippedCount: Int
    let cardsPerBatch: Int
    let contextSize: Int
    let model: GenerationModelKind
}

/// One generation run. Owns the plan, the dedup state and the model the plan was budgeted for.
@MainActor
private final class GenerationRun {

    private enum BatchOutcome {
        case completed
        case skipped
        /// The model changed mid-batch; the batch must be re-planned for the new budget.
        case interrupted
    }

    private let text: String
    private let cardCount: Int
    private let existingQuestions: [String]
    private let service: FlashcardGenerationService
    private let logManager: LogManager?
    private let emit: (GenerationEvent) -> Void

    private var filter: FlashcardQualityFilter
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

    init(
        text: String,
        cardCount: Int,
        existingQuestions: [String],
        service: FlashcardGenerationService,
        logManager: LogManager?,
        emit: @escaping (GenerationEvent) -> Void
    ) {
        self.text = text
        self.cardCount = cardCount
        self.existingQuestions = existingQuestions
        self.service = service
        self.logManager = logManager
        self.emit = emit
        self.filter = FlashcardQualityFilter(avoiding: existingQuestions)
    }

    func run() async throws -> GenerationRunSummary {
        guard case .available = service.availability else {
            throw GenerationFailure.modelUnavailable
        }

        announcedModel = service.beginRun()
        budgetModel = announcedModel
        tokensPerCharacter = Double(await service.tokenCount(text)) / Double(max(text.count, 1))
        overheadTokens = await service.tokenCount(FlashcardPrompt.instructions)
            + service.tokenCount(FlashcardPrompt.template)
            + service.schemaTokenCount()
        await measureBudget()

        var pending = plan(text, cardCount: cardCount)
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
                pending = plan(remaining.map(\.text).joined(), cardCount: remaining.map(\.cardCount).reduce(0, +))
            }
        }

        try await topUpIfShort()

        guard !acceptedQuestions.isEmpty else {
            throw lastFailure ?? (restrictedSkipCount > 0 ? .restricted : .unreadableText)
        }

        return GenerationRunSummary(
            requestedCount: cardCount,
            generatedCount: acceptedQuestions.count,
            batchCount: completedBatchCount + skippedBatchCount,
            skippedCount: skippedBatchCount,
            cardsPerBatch: budget.cardsPerBatch,
            contextSize: contextSize,
            model: announcedModel
        )
    }

    // MARK: Planning

    private func measureBudget() async {
        contextSize = await service.contextSize()
        budget = GenerationBudget(contextSize: contextSize, overheadTokens: overheadTokens, tokensPerCharacter: tokensPerCharacter)
    }

    private func plan(_ text: String, cardCount: Int) -> [GenerationBatch] {
        let batches = BatchPlanner.plan(text: text, cardCount: cardCount, budget: budget, firstIndex: nextIndex)
        nextIndex += batches.count
        plannedBatches += batches
        return batches
    }

    /// One extra batch on the largest chunk when filtering or skips left the run short of the requested count.
    private func topUpIfShort() async throws {
        let shortfall = cardCount - acceptedQuestions.count
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
                let cards = try await generate(pieces, index: batch.index, avoiding: avoiding)
                let accepted = filter.accept(cards)
                acceptedQuestions += accepted.map(\.question)
                completedBatchCount += 1
                emit(.batchCompleted(batch: batch.index, cards: accepted))
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

    /// Streams the pieces of one batch in order. Partial events carry every card the batch has so far.
    private func generate(_ pieces: [GenerationBatch], index: Int, avoiding: [String]) async throws -> [FlashcardModel] {
        var committed: [FlashcardModel] = []
        for piece in pieces {
            var ids: [String] = []
            var latest: [FlashcardModel] = []
            let prompt = FlashcardPrompt.prompt(cardCount: piece.cardCount, sourceText: piece.text, avoiding: avoiding)

            for try await drafts in service.streamCards(prompt: prompt, instructions: FlashcardPrompt.instructions) {
                announceModelChangeIfNeeded()
                let capped = drafts.prefix(piece.cardCount)
                while ids.count < capped.count {
                    ids.append(UUID().uuidString)
                }
                latest = zip(ids, capped).map { id, draft in
                    FlashcardModel(flashcardId: id, question: draft.question, answer: draft.answer)
                }
                let preview = latest.filter { FlashcardQualityFilter.isComplete(question: $0.question, answer: $0.answer) }
                emit(.partial(batch: index, cards: committed + preview))
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
        logManager?.trackEvent(event: FlashcardGenerationManager.Event.batchSkipped(batch: index, reason: reason, failure: lastFailure))
        emit(.batchSkipped(batch: index, reason: reason))
    }

    private func announceModelChangeIfNeeded() {
        let model = service.activeModel
        guard model != announcedModel else { return }
        logManager?.trackEvent(event: FlashcardGenerationManager.Event.modelFallback(fromModel: announcedModel, toModel: model))
        announcedModel = model
        emit(.modelChanged(model))
    }
}

// MARK: - Events

extension FlashcardGenerationManager {

    enum Event: LoggableEvent {
        case prewarm
        case generateStart(textLength: Int, cardCount: Int, avoidingCount: Int)
        case generateSuccess(summary: GenerationRunSummary)
        case generateFail(failure: GenerationFailure)
        case generateCancelled
        case batchSkipped(batch: Int, reason: SkipReason, failure: GenerationFailure?)
        case modelFallback(fromModel: GenerationModelKind, toModel: GenerationModelKind)
        case pdfExtractStart
        case pdfExtractSuccess(pageCount: Int, textLength: Int)
        case pdfExtractFail(error: Error)

        var eventName: String {
            switch self {
            case .prewarm:              return "FlashcardGenMan_Prewarm"
            case .generateStart:        return "FlashcardGenMan_Generate_Start"
            case .generateSuccess:      return "FlashcardGenMan_Generate_Success"
            case .generateFail:         return "FlashcardGenMan_Generate_Fail"
            case .generateCancelled:    return "FlashcardGenMan_Generate_Cancelled"
            case .batchSkipped:         return "FlashcardGenMan_BatchSkipped"
            case .modelFallback:        return "FlashcardGenMan_ModelFallback"
            case .pdfExtractStart:      return "FlashcardGenMan_PDFExtract_Start"
            case .pdfExtractSuccess:    return "FlashcardGenMan_PDFExtract_Success"
            case .pdfExtractFail:       return "FlashcardGenMan_PDFExtract_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .generateStart(textLength: let length, cardCount: let count, avoidingCount: let avoiding):
                return ["text_length": length, "card_count": count, "avoiding_count": avoiding]
            case .generateSuccess(summary: let summary):
                return [
                    "card_count": summary.requestedCount,
                    "generated_count": summary.generatedCount,
                    "batch_count": summary.batchCount,
                    "skipped_count": summary.skippedCount,
                    "cards_per_batch": summary.cardsPerBatch,
                    "context_size": summary.contextSize,
                    "model": summary.model.rawValue
                ]
            case .generateFail(failure: let failure):
                return ["failure": failure.analyticsName]
            case .batchSkipped(batch: let batch, reason: let reason, failure: let failure):
                var parameters: [String: Any] = ["batch_index": batch, "reason": reason.rawValue]
                if reason == .failed, let failure {
                    parameters["failure"] = failure.analyticsName
                }
                return parameters
            case .modelFallback(fromModel: let fromModel, toModel: let toModel):
                return ["from_model": fromModel.rawValue, "to_model": toModel.rawValue]
            case .pdfExtractSuccess(pageCount: let pages, textLength: let length):
                return ["page_count": pages, "text_length": length]
            case .pdfExtractFail(error: let error):
                return error.eventParameters
            case .prewarm, .generateCancelled, .pdfExtractStart:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .generateFail, .pdfExtractFail:
                return .severe
            case .batchSkipped, .modelFallback:
                return .warning
            default:
                return .analytic
            }
        }
    }
}
