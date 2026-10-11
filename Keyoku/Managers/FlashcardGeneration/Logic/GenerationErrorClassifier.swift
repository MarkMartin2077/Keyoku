//
//  GenerationErrorClassifier.swift
//  Keyoku
//

import Foundation
import FoundationModels

enum GenerationErrorClassifier {

    static func classify(_ error: any Error) -> GenerationFailure {
        switch error {
        case let failure as GenerationFailure:
            return failure
        case is CancellationError:
            return .cancelled
        case let error as LanguageModelError:
            return classify(error)
        case is PrivateCloudComputeLanguageModel.Error:
            return .cloudUnavailable
        case is SystemLanguageModel.Error:
            return .modelUnavailable
        case let error as LanguageModelSession.Error:
            // Calling a session that's still responding is a bug in the caller, not system load: don't back off and retry.
            return .other(String(describing: error))
        default:
            return legacyClassifier.classify(error) ?? .other(String(describing: error))
        }
    }

    private static func classify(_ error: LanguageModelError) -> GenerationFailure {
        switch error {
        case .contextSizeExceeded: return .contextTooLarge
        case .rateLimited(let info): return .rateLimited(retryAfter: info.resetDate)
        case .guardrailViolation: return .restricted
        case .refusal: return .refused
        case .unsupportedLanguageOrLocale: return .unsupportedLanguage
        case .timeout: return .other("timeout")
        case .unsupportedCapability, .unsupportedTranscriptContent, .unsupportedGenerationGuide:
            return .other(String(describing: error))
        @unknown default:
            return .other(String(describing: error))
        }
    }

    /// iOS 27 deprecates `LanguageModelSession.GenerationError` but the framework may still throw it.
    /// Calling through a protocol keeps the deprecated type out of non-deprecated call sites.
    private static let legacyClassifier: any LegacyGenerationErrorClassifying = LegacyGenerationErrorClassifier()
}

private protocol LegacyGenerationErrorClassifying: Sendable {
    func classify(_ error: any Error) -> GenerationFailure?
}

private struct LegacyGenerationErrorClassifier: LegacyGenerationErrorClassifying {

    @available(iOS, deprecated: 27.0)
    func classify(_ error: any Error) -> GenerationFailure? {
        guard let error = error as? LanguageModelSession.GenerationError else { return nil }
        switch error {
        case .exceededContextWindowSize: return .contextTooLarge
        case .assetsUnavailable: return .modelUnavailable
        case .guardrailViolation: return .restricted
        case .refusal: return .refused
        case .unsupportedLanguageOrLocale: return .unsupportedLanguage
        case .rateLimited: return .rateLimited(retryAfter: nil)
        case .concurrentRequests: return .other(String(describing: error))
        case .unsupportedGuide, .decodingFailure: return .other(String(describing: error))
        @unknown default: return .other(String(describing: error))
        }
    }
}
