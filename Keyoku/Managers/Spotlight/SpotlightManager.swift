//
//  SpotlightManager.swift
//  Keyoku
//

import Foundation
import CoreSpotlight

@MainActor
@Observable
class SpotlightManager {

    private let logManager: LogManager?

    init(logManager: LogManager? = nil) {
        self.logManager = logManager
    }

    // MARK: - Batch Indexing

    func indexAllContent(decks: [DeckModel], quizzes: [QuizModel]) {
        logManager?.trackEvent(event: Event.indexAllStart(deckCount: decks.count, quizCount: quizzes.count))

        Task.detached {
            let items = decks.map { Self.searchableItem(for: $0) }
                      + quizzes.map { Self.searchableItem(for: $0) }

            do {
                try await CSSearchableIndex.default().deleteAllSearchableItems()
                if !items.isEmpty {
                    try await CSSearchableIndex.default().indexSearchableItems(items)
                }
            } catch {
                await MainActor.run {
                    self.logManager?.trackEvent(event: Event.indexAllFail(error: error))
                }
            }
        }
    }

    // MARK: - Individual Indexing

    func indexDeck(_ deck: DeckModel) {
        logManager?.trackEvent(event: Event.indexDeck(deckId: deck.deckId))

        let item = Self.searchableItem(for: deck)
        Task.detached {
            try? await CSSearchableIndex.default().indexSearchableItems([item])
        }
    }

    func indexQuiz(_ quiz: QuizModel) {
        logManager?.trackEvent(event: Event.indexQuiz(quizId: quiz.quizId))

        let item = Self.searchableItem(for: quiz)
        Task.detached {
            try? await CSSearchableIndex.default().indexSearchableItems([item])
        }
    }

    // MARK: - Removal

    func removeDeck(id: String) {
        logManager?.trackEvent(event: Event.removeDeck(deckId: id))

        Task.detached {
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["deck-\(id)"])
        }
    }

    func removeQuiz(id: String) {
        logManager?.trackEvent(event: Event.removeQuiz(quizId: id))

        Task.detached {
            try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["quiz-\(id)"])
        }
    }

    func removeAllItems() {
        logManager?.trackEvent(event: Event.removeAll)

        Task.detached {
            try? await CSSearchableIndex.default().deleteAllSearchableItems()
        }
    }

    // MARK: - Identifier Parsing

    func parseSpotlightIdentifier(_ identifier: String) -> (type: String, id: String)? {
        let parts = identifier.split(separator: "-", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (type: String(parts[0]), id: String(parts[1]))
    }

    // MARK: - Searchable Items

    private nonisolated static func searchableItem(for deck: DeckModel) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = deck.name
        attributes.contentDescription = "\(deck.flashcards.count) card\(deck.flashcards.count == 1 ? "" : "s")"
        attributes.keywords = ["deck", "flashcards", "study"]

        return CSSearchableItem(
            uniqueIdentifier: "deck-\(deck.deckId)",
            domainIdentifier: "com.keyoku.deck",
            attributeSet: attributes
        )
    }

    private nonisolated static func searchableItem(for quiz: QuizModel) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .content)
        attributes.title = quiz.name
        attributes.contentDescription = "\(quiz.questions.count) question\(quiz.questions.count == 1 ? "" : "s")"
        attributes.keywords = ["quiz", "test", "study"]

        return CSSearchableItem(
            uniqueIdentifier: "quiz-\(quiz.quizId)",
            domainIdentifier: "com.keyoku.quiz",
            attributeSet: attributes
        )
    }

    // MARK: - Events

    enum Event: LoggableEvent {
        case indexAllStart(deckCount: Int, quizCount: Int)
        case indexAllFail(error: Error)
        case indexDeck(deckId: String)
        case indexQuiz(quizId: String)
        case removeDeck(deckId: String)
        case removeQuiz(quizId: String)
        case removeAll

        var eventName: String {
            switch self {
            case .indexAllStart:     return "SpotlightMan_IndexAll_Start"
            case .indexAllFail:      return "SpotlightMan_IndexAll_Fail"
            case .indexDeck:         return "SpotlightMan_IndexDeck"
            case .indexQuiz:         return "SpotlightMan_IndexQuiz"
            case .removeDeck:       return "SpotlightMan_RemoveDeck"
            case .removeQuiz:       return "SpotlightMan_RemoveQuiz"
            case .removeAll:        return "SpotlightMan_RemoveAll"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .indexAllStart(deckCount: let deckCount, quizCount: let quizCount):
                return ["deck_count": deckCount, "quiz_count": quizCount]
            case .indexAllFail(error: let error):
                return error.eventParameters
            case .indexDeck(deckId: let id):
                return ["deck_id": id]
            case .indexQuiz(quizId: let id):
                return ["quiz_id": id]
            case .removeDeck(deckId: let id):
                return ["deck_id": id]
            case .removeQuiz(quizId: let id):
                return ["quiz_id": id]
            case .removeAll:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .indexAllFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
