//
//  QuizGenerationManager.swift
//  Keyoku
//

import Foundation

/// Generates a quiz's questions and title from a deck's source text. It doesn't save anything:
/// the interactor saves the result through `QuizManager.createQuiz`.
///
/// Questions come from the shared `GenerationRun` (budgeting, chunking, retries, model fallback, one top-up).
/// A run fails unless at least `QuizQuestionCount.minimum` questions pass the quality filter.
/// The title comes from a separate on-device call over the accepted questions, falling back to "<Deck name> Quiz".
@MainActor
@Observable
final class QuizGenerationManager {

    /// The prompt asks for six words; a little slack avoids discarding a good title over one extra word.
    static let maxTitleWords = 8

    private let service: QuizGenerationService
    private let logManager: LogManager?

    init(service: QuizGenerationService, logManager: LogManager? = nil) {
        self.service = service
        self.logManager = logManager
    }

    var generationAvailability: GenerationAvailability {
        service.availability
    }

    func prewarmGeneration() {
        logManager?.trackEvent(event: Event.prewarm)
        service.prewarm(instructions: QuizPrompt.instructions)
    }

    /// - Parameters:
    ///   - count: Clamped to what the source text allows (`QuizQuestionCount`).
    ///   - existingQuestions: The deck's other quiz questions, oldest first. The newest are kept when the prompt can't fit them all.
    ///   - onProgress: Counts only; never question text.
    /// - Throws: `QuizGenerationError`. Cancelling the task throws `.generation(.cancelled)`.
    func generateQuiz(
        from sourceText: String,
        deckName: String,
        count: Int,
        avoiding existingQuestions: [String],
        onProgress: @escaping (QuizGenerationProgress) -> Void
    ) async throws -> GeneratedQuiz {
        let questionCount = QuizQuestionCount.clamped(count, sourceLength: sourceText.count)
        logManager?.trackEvent(event: Event.generateStart(
            textLength: sourceText.count,
            questionCount: questionCount,
            avoidingCount: existingQuestions.count
        ))

        do {
            guard QuizQuestionCount.canMakeQuiz(sourceLength: sourceText.count) else {
                throw QuizGenerationError.notEnoughSourceText
            }
            let (questions, summary) = try await generateQuestions(
                from: sourceText,
                count: questionCount,
                avoiding: existingQuestions,
                onProgress: onProgress
            )
            guard questions.count >= QuizQuestionCount.minimum else {
                throw QuizGenerationError.tooFewQuestions(generated: questions.count)
            }
            let (title, usedFallbackTitle) = await makeTitle(for: questions, deckName: deckName)
            try Task.checkCancellation()

            let quiz = GeneratedQuiz(title: title, questions: questions, usedFallbackTitle: usedFallbackTitle)
            logManager?.trackEvent(event: Event.generateSuccess(summary: summary, usedFallbackTitle: usedFallbackTitle))
            return quiz
        } catch {
            let failure = (error as? QuizGenerationError) ?? .generation(GenerationErrorClassifier.classify(error))
            if failure.isCancelled {
                logManager?.trackEvent(event: Event.generateCancelled)
            } else {
                logManager?.trackEvent(event: Event.generateFail(failure: failure))
            }
            throw failure
        }
    }

    // MARK: Questions

    private func generateQuestions(
        from sourceText: String,
        count: Int,
        avoiding existingQuestions: [String],
        onProgress: @escaping (QuizGenerationProgress) -> Void
    ) async throws -> (questions: [QuizQuestionModel], summary: GenerationRunSummary) {
        let logManager = logManager
        var counter = QuizProgressCounter(totalCount: count)
        let run = GenerationRun(
            text: sourceText,
            itemCount: count,
            existingQuestions: existingQuestions,
            service: service,
            strategy: QuizGenerationStrategy(service: service, avoiding: existingQuestions),
            emit: { event in
                switch event {
                case .batchSkipped(batch: let batch, reason: let reason, failure: let failure):
                    logManager?.trackEvent(event: Event.batchSkipped(batch: batch, reason: reason, failure: failure))
                case .modelChanged(from: let fromModel, to: let toModel):
                    logManager?.trackEvent(event: Event.modelFallback(fromModel: fromModel, toModel: toModel))
                default:
                    break
                }
                if let progress = counter.apply(event) {
                    onProgress(progress)
                }
            }
        )
        let summary = try await run.run()
        return (Array(counter.acceptedQuestions.prefix(count)), summary)
    }

    // MARK: Title

    private func makeTitle(for questions: [QuizQuestionModel], deckName: String) async -> (title: String, usedFallback: Bool) {
        logManager?.trackEvent(event: Event.titleStart)
        do {
            let generated = try await service.generateQuizTitle(
                prompt: QuizPrompt.titlePrompt(questions: questions.map(\.question)),
                instructions: QuizPrompt.titleInstructions
            )
            if let title = Self.cleanedTitle(generated) {
                logManager?.trackEvent(event: Event.titleSuccess(wordCount: title.split(separator: " ").count))
                return (title, false)
            }
            logManager?.trackEvent(event: Event.titleFallback(reason: "invalid_title"))
        } catch {
            logManager?.trackEvent(event: Event.titleFallback(reason: GenerationErrorClassifier.classify(error).analyticsName))
        }
        return (Self.fallbackTitle(deckName: deckName), true)
    }

    /// The title without surrounding quotes or extra whitespace, or nil when it's empty or too long.
    static func cleanedTitle(_ title: String) -> String? {
        let words = title
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"'“”‘’")))
            .split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty, words.count <= maxTitleWords else { return nil }
        return words.joined(separator: " ")
    }

    static func fallbackTitle(deckName: String) -> String {
        let name = deckName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? String(localized: "Quiz") : String(localized: "\(name) Quiz")
    }
}

// MARK: - Progress

/// Turns run events into count-only progress and collects the accepted questions.
/// The count includes finished questions still streaming in the current batch, and never goes backwards.
private struct QuizProgressCounter {
    let totalCount: Int
    private(set) var acceptedQuestions: [QuizQuestionModel] = []
    private var reportedCount: Int?

    init(totalCount: Int) {
        self.totalCount = totalCount
    }

    /// The new progress, or nil when the count didn't change.
    mutating func apply(_ event: GenerationRunEvent<QuizQuestionModel>) -> QuizGenerationProgress? {
        var count = acceptedQuestions.count
        switch event {
        case .partial(batch: _, items: let items):
            count += items.count
        case .batchCompleted(batch: _, items: let items):
            acceptedQuestions += items
            count = acceptedQuestions.count
        case .started, .modelChanged, .batchSkipped:
            break
        }

        let newCount = min(max(count, reportedCount ?? 0), totalCount)
        guard newCount != reportedCount else { return nil }
        reportedCount = newCount
        return QuizGenerationProgress(generatedCount: newCount, totalCount: totalCount)
    }
}

// MARK: - Events

extension QuizGenerationManager {

    enum Event: LoggableEvent {
        case prewarm
        case generateStart(textLength: Int, questionCount: Int, avoidingCount: Int)
        case generateSuccess(summary: GenerationRunSummary, usedFallbackTitle: Bool)
        case generateFail(failure: QuizGenerationError)
        case generateCancelled
        case batchSkipped(batch: Int, reason: SkipReason, failure: GenerationFailure?)
        case modelFallback(fromModel: GenerationModelKind, toModel: GenerationModelKind)
        case titleStart
        case titleSuccess(wordCount: Int)
        case titleFallback(reason: String)

        var eventName: String {
            switch self {
            case .prewarm:              return "QuizGenMan_Prewarm"
            case .generateStart:        return "QuizGenMan_Generate_Start"
            case .generateSuccess:      return "QuizGenMan_Generate_Success"
            case .generateFail:         return "QuizGenMan_Generate_Fail"
            case .generateCancelled:    return "QuizGenMan_Generate_Cancelled"
            case .batchSkipped:         return "QuizGenMan_BatchSkipped"
            case .modelFallback:        return "QuizGenMan_ModelFallback"
            case .titleStart:           return "QuizGenMan_Title_Start"
            case .titleSuccess:         return "QuizGenMan_Title_Success"
            case .titleFallback:        return "QuizGenMan_Title_Fallback"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .generateStart(textLength: let length, questionCount: let count, avoidingCount: let avoiding):
                return ["text_length": length, "question_count": count, "avoiding_count": avoiding]
            case .generateSuccess(summary: let summary, usedFallbackTitle: let usedFallbackTitle):
                return [
                    "question_count": summary.requestedCount,
                    "generated_count": summary.generatedCount,
                    "batch_count": summary.batchCount,
                    "skipped_count": summary.skippedCount,
                    "questions_per_batch": summary.itemsPerBatch,
                    "context_size": summary.contextSize,
                    "model": summary.model.rawValue,
                    "used_fallback_title": usedFallbackTitle
                ]
            case .generateFail(failure: let failure):
                var parameters: [String: Any] = ["failure": failure.analyticsName]
                if case .tooFewQuestions(generated: let generated) = failure {
                    parameters["generated_count"] = generated
                }
                return parameters
            case .batchSkipped(batch: let batch, reason: let reason, failure: let failure):
                var parameters: [String: Any] = ["batch_index": batch, "reason": reason.rawValue]
                if reason == .failed, let failure {
                    parameters["failure"] = failure.analyticsName
                }
                return parameters
            case .modelFallback(fromModel: let fromModel, toModel: let toModel):
                return ["from_model": fromModel.rawValue, "to_model": toModel.rawValue]
            case .titleSuccess(wordCount: let wordCount):
                return ["word_count": wordCount]
            case .titleFallback(reason: let reason):
                return ["reason": reason]
            case .prewarm, .generateCancelled, .titleStart:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .generateFail:
                return .severe
            case .batchSkipped, .modelFallback, .titleFallback:
                return .warning
            default:
                return .analytic
            }
        }
    }
}
