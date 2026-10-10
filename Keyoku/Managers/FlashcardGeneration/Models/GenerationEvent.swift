//
//  GenerationEvent.swift
//  Keyoku
//

import Foundation

enum GenerationModelKind: String, Sendable {
    case privateCloud
    case onDevice

    var displayName: String {
        switch self {
        case .privateCloud: return String(localized: "Private Cloud Compute")
        case .onDevice: return String(localized: "On-device")
        }
    }
}

enum GenerationAvailability: Equatable, Sendable {
    case available(GenerationModelKind)
    case unavailable(UnavailableReason)
}

enum UnavailableReason: Sendable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknown
}

struct GenerationBatch: Equatable, Sendable {
    let index: Int
    let text: String
    let cardCount: Int
}

enum GenerationFailure: Error, Equatable {
    case contextTooLarge
    case restricted
    case rateLimited(retryAfter: Date?)
    case unsupportedLanguage
    case modelUnavailable
    /// Private Cloud Compute failed in a way that on-device generation can recover from.
    case cloudUnavailable
    case cancelled
    case unreadableText
    case other(String)

    var userMessage: String {
        switch self {
        case .contextTooLarge:
            return String(localized: "This text is too long to process in one go. Try a shorter excerpt.")
        case .restricted:
            return String(localized: "Apple Intelligence couldn't create flashcards from this content because of its safety guidelines. Try different study material.")
        case .rateLimited:
            return String(localized: "Apple Intelligence is busy right now. Wait a moment and try again.")
        case .unsupportedLanguage:
            return String(localized: "This text's language isn't supported by Apple Intelligence yet.")
        case .modelUnavailable:
            return String(localized: "Apple Intelligence isn't available right now. Check that it's turned on in Settings, then try again.")
        case .cloudUnavailable:
            return String(localized: "Couldn't reach Private Cloud Compute. Check your connection and try again.")
        case .cancelled:
            return String(localized: "Generation was cancelled.")
        case .unreadableText:
            return String(localized: "No flashcards could be generated from this text. Try pasting actual study material like notes, a textbook excerpt, or an article.")
        case .other:
            return String(localized: "Something went wrong while generating flashcards. Please try again.")
        }
    }

    var analyticsName: String {
        switch self {
        case .contextTooLarge: return "context_too_large"
        case .restricted: return "restricted"
        case .rateLimited: return "rate_limited"
        case .unsupportedLanguage: return "unsupported_language"
        case .modelUnavailable: return "model_unavailable"
        case .cloudUnavailable: return "cloud_unavailable"
        case .cancelled: return "cancelled"
        case .unreadableText: return "unreadable_text"
        case .other: return "other"
        }
    }
}

enum SkipReason: String, Sendable {
    case unreadableText
    case restricted
    case failed
}

enum GenerationEvent: Sendable {
    case started(model: GenerationModelKind, batchCount: Int)
    /// Private Cloud Compute became unusable mid-run; the rest of the run is on-device.
    case modelChanged(GenerationModelKind)
    /// Streaming preview that replaces the batch's previous partial.
    case partial(batch: Int, cards: [FlashcardModel])
    /// Filtered and deduplicated cards; final for that batch.
    case batchCompleted(batch: Int, cards: [FlashcardModel])
    /// The batch's partial cards are discarded.
    case batchSkipped(batch: Int, reason: SkipReason)
}
