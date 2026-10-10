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
        let logManager = logManager
        let run = GenerationRun(
            text: text,
            itemCount: count,
            existingQuestions: existingQuestions,
            service: service,
            strategy: FlashcardGenerationStrategy(service: service, avoiding: existingQuestions),
            emit: { event in
                switch event {
                case .batchSkipped(batch: let batch, reason: let reason, failure: let failure):
                    logManager?.trackEvent(event: Event.batchSkipped(batch: batch, reason: reason, failure: failure))
                case .modelChanged(from: let fromModel, to: let toModel):
                    logManager?.trackEvent(event: Event.modelFallback(fromModel: fromModel, toModel: toModel))
                default:
                    break
                }
                continuation.yield(GenerationEvent(event))
            }
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
                    "cards_per_batch": summary.itemsPerBatch,
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

// MARK: - Run events

private extension GenerationEvent {

    init(_ event: GenerationRunEvent<FlashcardModel>) {
        switch event {
        case .started(model: let model, batchCount: let batchCount):
            self = .started(model: model, batchCount: batchCount)
        case .modelChanged(from: _, to: let model):
            self = .modelChanged(model)
        case .partial(batch: let batch, items: let cards):
            self = .partial(batch: batch, cards: cards)
        case .batchCompleted(batch: let batch, items: let cards):
            self = .batchCompleted(batch: batch, cards: cards)
        case .batchSkipped(batch: let batch, reason: let reason, failure: _):
            self = .batchSkipped(batch: batch, reason: reason)
        }
    }
}
