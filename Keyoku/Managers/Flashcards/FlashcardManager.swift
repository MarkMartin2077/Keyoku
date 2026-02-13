//
//  FlashcardManager.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

/// Manages deck and flashcard CRUD operations using a local-first architecture with remote backup.
///
/// **Data Flow:**
/// 1. All writes go to local storage first (synchronous, immediate)
/// 2. The in-memory `decks` array is updated to reflect the change
/// 3. A fire-and-forget `Task` pushes the change to the remote service
///
/// **Login Sync:**
/// On `logIn`, remote decks are fetched and merged into local storage.
/// If the remote fetch fails, the manager falls back to whatever is cached locally.
///
/// **Flashcard Ownership:**
/// Flashcards are stored as children of their parent `DeckModel`. When a flashcard
/// is added or removed, the entire `DeckModel` is reconstructed with the updated
/// flashcard list and saved back to both local and remote storage.
///
/// **Dependencies:**
/// - `DeckService` (local) — synchronous, file-based persistence for decks and flashcards
/// - `RemoteDeckService` (remote) — async, typically Firestore-backed
/// - `LogManager` — optional analytics tracking for every operation
@MainActor
@Observable
class FlashcardManager {

    private let local: DeckService
    private let remote: RemoteDeckService
    private let logManager: LogManager?
    private var userId: String?

    /// The current user's decks (including their flashcards), loaded from local storage.
    /// Updated in-place on create/update/delete to avoid full reloads.
    private(set) var decks: [DeckModel] = []

    init(services: FlashcardServices, logManager: LogManager? = nil) {
        self.local = services.local
        self.remote = services.remote
        self.logManager = logManager
    }

    // MARK: - Auth Lifecycle

    /// Syncs remote decks to local storage and loads them into memory.
    ///
    /// Remote decks are saved locally one at a time using `try?` so that a
    /// single corrupt deck doesn't prevent the rest from syncing. If the entire
    /// remote fetch fails, the manager falls back to whatever is already cached locally.
    ///
    /// - Parameter userId: The authenticated user's ID, stored for remote operations.
    func logIn(userId: String) async throws {
        self.userId = userId
        logManager?.trackEvent(event: Event.logInStart(userId: userId))

        do {
            let remoteDecks = try await remote.getAllDecks(userId: userId)
            for deck in remoteDecks {
                try? local.saveDeck(deck: deck)
            }
            loadDecks()
            logManager?.trackEvent(event: Event.logInSuccess(userId: userId, count: decks.count))
        } catch {
            logManager?.trackEvent(event: Event.logInFail(error: error))
            loadDecks()
        }
    }

    /// Clears the userId and in-memory decks. Local storage is not deleted.
    func signOut() {
        logManager?.trackEvent(event: Event.signOut)
        userId = nil
        decks = []
    }

    // MARK: - Deck Operations

    /// Reloads all decks from local storage into the in-memory `decks` array.
    /// Errors are logged but do not throw — the array simply remains unchanged.
    func loadDecks() {
        logManager?.trackEvent(event: Event.loadDecksStart)

        do {
            decks = try local.getAllDecks()
            logManager?.trackEvent(event: Event.loadDecksSuccess(count: decks.count))
        } catch {
            logManager?.trackEvent(event: Event.loadDecksFail(error: error))
        }
    }

    /// Returns a deck from the in-memory array by its ID, or `nil` if not found.
    func getDeck(id: String) -> DeckModel? {
        decks.first { $0.deckId == id }
    }

    /// Creates an empty deck (no flashcards) and persists it locally.
    ///
    /// The deck is inserted at index 0 so it appears first in the list,
    /// then pushed to remote in the background.
    ///
    /// - Parameters:
    ///   - name: Display name for the deck.
    ///   - color: Theme color (defaults to `.blue`).
    ///   - imageUrl: Optional cover image path (relative to Documents directory).
    ///   - sourceText: The original text used to generate the deck.
    func createDeck(name: String, color: DeckColor = .blue, imageUrl: String? = nil, sourceText: String) throws {
        logManager?.trackEvent(event: Event.createDeckStart(name: name))

        let deck = DeckModel(name: name, color: color, imageUrl: imageUrl, sourceText: sourceText)

        do {
            try local.saveDeck(deck: deck)
            decks.insert(deck, at: 0)
            logManager?.trackEvent(event: Event.createDeckSuccess(deck: deck))
            pushDeckToRemote(deck)
        } catch {
            logManager?.trackEvent(event: Event.createDeckFail(error: error))
            throw error
        }
    }

    /// Creates a deck with pre-generated flashcards.
    ///
    /// A new `deckId` is generated, and each flashcard's `deckId` field is
    /// remapped to match it. This ensures consistent parent-child relationships
    /// even when flashcards were generated before the deck existed (e.g., from AI generation).
    ///
    /// - Parameters:
    ///   - name: Display name for the deck.
    ///   - color: Theme color (defaults to `.blue`).
    ///   - imageUrl: Optional cover image path (relative to Documents directory).
    ///   - sourceText: The original text used to generate the deck.
    ///   - flashcards: Pre-generated flashcards whose `deckId` will be overwritten.
    func createDeck(name: String, color: DeckColor = .blue, imageUrl: String? = nil, sourceText: String, flashcards: [FlashcardModel]) throws {
        logManager?.trackEvent(event: Event.createDeckStart(name: name))

        let deckId = UUID().uuidString
        let flashcardsWithDeckId = flashcards.map { card in
            FlashcardModel(
                flashcardId: card.flashcardId,
                question: card.question,
                answer: card.answer,
                deckId: deckId
            )
        }

        let deck = DeckModel(
            deckId: deckId,
            name: name,
            color: color,
            imageUrl: imageUrl,
            sourceText: sourceText,
            flashcards: flashcardsWithDeckId
        )

        do {
            try local.saveDeck(deck: deck)
            decks.insert(deck, at: 0)
            logManager?.trackEvent(event: Event.createDeckSuccess(deck: deck))
            pushDeckToRemote(deck)
        } catch {
            logManager?.trackEvent(event: Event.createDeckFail(error: error))
            throw error
        }
    }

    /// Replaces an existing deck in local storage and updates the in-memory array.
    ///
    /// Finds the deck by `deckId` and swaps it in-place. If the deck isn't found
    /// in the in-memory array, local storage is still updated but the array isn't modified.
    func updateDeck(_ deck: DeckModel) throws {
        logManager?.trackEvent(event: Event.updateDeckStart(deck: deck))

        do {
            try local.saveDeck(deck: deck)
            if let index = decks.firstIndex(where: { $0.deckId == deck.deckId }) {
                decks[index] = deck
            }
            logManager?.trackEvent(event: Event.updateDeckSuccess(deck: deck))
            pushDeckToRemote(deck)
        } catch {
            logManager?.trackEvent(event: Event.updateDeckFail(error: error))
            throw error
        }
    }

    /// Deletes a deck from local storage and removes it from the in-memory array.
    /// The remote deletion happens in the background via fire-and-forget.
    func deleteDeck(id: String) throws {
        logManager?.trackEvent(event: Event.deleteDeckStart(deckId: id))

        do {
            try local.deleteDeck(id: id)
            decks.removeAll { $0.deckId == id }
            logManager?.trackEvent(event: Event.deleteDeckSuccess(deckId: id))
            deleteDeckFromRemote(deckId: id)
        } catch {
            logManager?.trackEvent(event: Event.deleteDeckFail(error: error))
            throw error
        }
    }

    // MARK: - Image Operations

    /// Saves JPEG image data to the app's Documents directory under `deck_images/`.
    ///
    /// Creates the `deck_images/` subdirectory if it doesn't exist. The file is
    /// named with a UUID to avoid collisions.
    ///
    /// - Parameter data: Raw JPEG image data.
    /// - Returns: The relative file path (e.g., `"deck_images/abc-123.jpg"`), suitable
    ///   for storing in a `DeckModel.imageUrl` and resolving later against the Documents directory.
    func saveDeckImage(data: Data) throws -> String {
        let fileName = "deck_images/\(UUID().uuidString).jpg"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)

        let directoryURL = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        try data.write(to: fileURL)
        logManager?.trackEvent(event: Event.saveDeckImageSuccess(fileName: fileName))
        return fileName
    }

    // MARK: - Flashcard Operations

    /// Adds a single flashcard to an existing deck.
    ///
    /// Because `DeckModel` is a value type, the entire deck is reconstructed
    /// with the new flashcard appended to its `flashcards` array. The updated
    /// deck is then saved locally and pushed to remote.
    ///
    /// - Parameters:
    ///   - question: The flashcard's question text.
    ///   - answer: The flashcard's answer text.
    ///   - toDeckId: The parent deck's ID.
    func addFlashcard(question: String, answer: String, toDeckId: String) throws {
        logManager?.trackEvent(event: Event.addFlashcardStart(deckId: toDeckId))

        let flashcard = FlashcardModel(question: question, answer: answer, deckId: toDeckId)

        do {
            try local.addFlashcard(flashcard: flashcard, toDeckId: toDeckId)

            // Reconstruct the DeckModel with the new flashcard appended
            if let deckIndex = decks.firstIndex(where: { $0.deckId == toDeckId }) {
                let deck = decks[deckIndex]
                let updatedDeck = DeckModel(
                    deckId: deck.deckId,
                    name: deck.name,
                    color: deck.color,
                    imageUrl: deck.imageUrl,
                    sourceText: deck.sourceText,
                    createdAt: deck.createdAt,
                    flashcards: deck.flashcards + [flashcard]
                )
                decks[deckIndex] = updatedDeck
                pushDeckToRemote(updatedDeck)
            }

            logManager?.trackEvent(event: Event.addFlashcardSuccess(flashcard: flashcard))
        } catch {
            logManager?.trackEvent(event: Event.addFlashcardFail(error: error))
            throw error
        }
    }

    /// Removes a flashcard from its parent deck.
    ///
    /// The flashcard is deleted from local storage, then the parent `DeckModel`
    /// is reconstructed with the flashcard filtered out. The updated deck
    /// is saved locally and pushed to remote.
    ///
    /// - Parameters:
    ///   - id: The flashcard's ID.
    ///   - fromDeckId: The parent deck's ID (needed to locate and update the deck).
    func deleteFlashcard(id: String, fromDeckId: String) throws {
        logManager?.trackEvent(event: Event.deleteFlashcardStart(flashcardId: id))

        do {
            try local.deleteFlashcard(id: id)

            // Reconstruct the DeckModel with the flashcard filtered out
            if let deckIndex = decks.firstIndex(where: { $0.deckId == fromDeckId }) {
                let deck = decks[deckIndex]
                let updatedDeck = DeckModel(
                    deckId: deck.deckId,
                    name: deck.name,
                    color: deck.color,
                    imageUrl: deck.imageUrl,
                    sourceText: deck.sourceText,
                    createdAt: deck.createdAt,
                    flashcards: deck.flashcards.filter { $0.flashcardId != id }
                )
                decks[deckIndex] = updatedDeck
                pushDeckToRemote(updatedDeck)
            }

            logManager?.trackEvent(event: Event.deleteFlashcardSuccess(flashcardId: id))
        } catch {
            logManager?.trackEvent(event: Event.deleteFlashcardFail(error: error))
            throw error
        }
    }

    // MARK: - Remote Sync Helpers

    /// Pushes a deck to the remote service in the background.
    /// Failures are logged but do not surface to the caller (fire-and-forget).
    /// No-ops if the user is not signed in.
    private func pushDeckToRemote(_ deck: DeckModel) {
        guard let userId else { return }
        Task {
            do {
                try await remote.saveDeck(userId: userId, deck: deck)
                logManager?.trackEvent(event: Event.remotePushSuccess(deckId: deck.deckId))
            } catch {
                logManager?.trackEvent(event: Event.remotePushFail(error: error))
            }
        }
    }

    /// Deletes a deck from the remote service in the background.
    /// Failures are logged but do not surface to the caller (fire-and-forget).
    /// No-ops if the user is not signed in.
    private func deleteDeckFromRemote(deckId: String) {
        guard let userId else { return }
        Task {
            do {
                try await remote.deleteDeck(userId: userId, deckId: deckId)
                logManager?.trackEvent(event: Event.remoteDeleteSuccess(deckId: deckId))
            } catch {
                logManager?.trackEvent(event: Event.remoteDeleteFail(error: error))
            }
        }
    }

    // MARK: - Events
    
    enum Event: LoggableEvent {
        case loadDecksStart
        case loadDecksSuccess(count: Int)
        case loadDecksFail(error: Error)
        case createDeckStart(name: String)
        case createDeckSuccess(deck: DeckModel)
        case createDeckFail(error: Error)
        case updateDeckStart(deck: DeckModel)
        case updateDeckSuccess(deck: DeckModel)
        case updateDeckFail(error: Error)
        case deleteDeckStart(deckId: String)
        case deleteDeckSuccess(deckId: String)
        case deleteDeckFail(error: Error)
        case addFlashcardStart(deckId: String)
        case addFlashcardSuccess(flashcard: FlashcardModel)
        case addFlashcardFail(error: Error)
        case deleteFlashcardStart(flashcardId: String)
        case deleteFlashcardSuccess(flashcardId: String)
        case deleteFlashcardFail(error: Error)
        case saveDeckImageSuccess(fileName: String)
        case logInStart(userId: String)
        case logInSuccess(userId: String, count: Int)
        case logInFail(error: Error)
        case signOut
        case remotePushSuccess(deckId: String)
        case remotePushFail(error: Error)
        case remoteDeleteSuccess(deckId: String)
        case remoteDeleteFail(error: Error)

        var eventName: String {
            switch self {
            case .loadDecksStart:           return "FlashcardMan_LoadDecks_Start"
            case .loadDecksSuccess:         return "FlashcardMan_LoadDecks_Success"
            case .loadDecksFail:            return "FlashcardMan_LoadDecks_Fail"
            case .createDeckStart:          return "FlashcardMan_CreateDeck_Start"
            case .createDeckSuccess:        return "FlashcardMan_CreateDeck_Success"
            case .createDeckFail:           return "FlashcardMan_CreateDeck_Fail"
            case .updateDeckStart:          return "FlashcardMan_UpdateDeck_Start"
            case .updateDeckSuccess:        return "FlashcardMan_UpdateDeck_Success"
            case .updateDeckFail:           return "FlashcardMan_UpdateDeck_Fail"
            case .deleteDeckStart:          return "FlashcardMan_DeleteDeck_Start"
            case .deleteDeckSuccess:        return "FlashcardMan_DeleteDeck_Success"
            case .deleteDeckFail:           return "FlashcardMan_DeleteDeck_Fail"
            case .addFlashcardStart:        return "FlashcardMan_AddFlashcard_Start"
            case .addFlashcardSuccess:      return "FlashcardMan_AddFlashcard_Success"
            case .addFlashcardFail:         return "FlashcardMan_AddFlashcard_Fail"
            case .deleteFlashcardStart:     return "FlashcardMan_DeleteFlashcard_Start"
            case .deleteFlashcardSuccess:   return "FlashcardMan_DeleteFlashcard_Success"
            case .deleteFlashcardFail:      return "FlashcardMan_DeleteFlashcard_Fail"
            case .saveDeckImageSuccess:     return "FlashcardMan_SaveDeckImage_Success"
            case .logInStart:               return "FlashcardMan_LogIn_Start"
            case .logInSuccess:             return "FlashcardMan_LogIn_Success"
            case .logInFail:                return "FlashcardMan_LogIn_Fail"
            case .signOut:                  return "FlashcardMan_SignOut"
            case .remotePushSuccess:        return "FlashcardMan_RemotePush_Success"
            case .remotePushFail:           return "FlashcardMan_RemotePush_Fail"
            case .remoteDeleteSuccess:      return "FlashcardMan_RemoteDelete_Success"
            case .remoteDeleteFail:         return "FlashcardMan_RemoteDelete_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .loadDecksSuccess(count: let count):
                return ["deck_count": count]
            case .logInSuccess(userId: let userId, count: let count):
                return ["user_id": userId, "deck_count": count]
            case .logInStart(userId: let userId):
                return ["user_id": userId]
            case .createDeckStart(name: let name):
                return ["deck_name": name]
            case .createDeckSuccess(deck: let deck), .updateDeckStart(deck: let deck), .updateDeckSuccess(deck: let deck):
                return deck.eventParameters
            case .deleteDeckStart(deckId: let id), .deleteDeckSuccess(deckId: let id), .remotePushSuccess(deckId: let id), .remoteDeleteSuccess(deckId: let id):
                return ["deck_id": id]
            case .addFlashcardStart(deckId: let id):
                return ["deck_id": id]
            case .addFlashcardSuccess(flashcard: let flashcard):
                return flashcard.eventParameters
            case .deleteFlashcardStart(flashcardId: let id), .deleteFlashcardSuccess(flashcardId: let id):
                return ["flashcard_id": id]
            case .saveDeckImageSuccess(fileName: let fileName):
                return ["file_name": fileName]
            case .loadDecksFail(error: let error),
                    .createDeckFail(error: let error),
                    .updateDeckFail(error: let error),
                    .deleteDeckFail(error: let error),
                    .addFlashcardFail(error: let error),
                    .deleteFlashcardFail(error: let error),
                    .logInFail(error: let error),
                    .remotePushFail(error: let error),
                    .remoteDeleteFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .loadDecksFail, .createDeckFail, .updateDeckFail, .deleteDeckFail, .addFlashcardFail, .deleteFlashcardFail, .logInFail, .remotePushFail, .remoteDeleteFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
