//
//  FlashcardManager.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
@Observable
class FlashcardManager {

    private let local: DeckService
    private let remote: RemoteDeckService
    private let logManager: LogManager?
    private var userId: String?

    private(set) var decks: [DeckModel] = []

    init(services: FlashcardServices, logManager: LogManager? = nil) {
        self.local = services.local
        self.remote = services.remote
        self.logManager = logManager
    }

    // MARK: - Auth Lifecycle

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

    func signOut() {
        logManager?.trackEvent(event: Event.signOut)
        userId = nil
        decks = []
    }
    
    // MARK: - Deck Operations
    
    func loadDecks() {
        logManager?.trackEvent(event: Event.loadDecksStart)
        
        do {
            decks = try local.getAllDecks()
            logManager?.trackEvent(event: Event.loadDecksSuccess(count: decks.count))
        } catch {
            logManager?.trackEvent(event: Event.loadDecksFail(error: error))
        }
    }
    
    func getDeck(id: String) -> DeckModel? {
        decks.first { $0.deckId == id }
    }
    
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
    
    func addFlashcard(question: String, answer: String, toDeckId: String) throws {
        logManager?.trackEvent(event: Event.addFlashcardStart(deckId: toDeckId))

        let flashcard = FlashcardModel(question: question, answer: answer, deckId: toDeckId)

        do {
            try local.addFlashcard(flashcard: flashcard, toDeckId: toDeckId)

            // Update local state
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
    
    func deleteFlashcard(id: String, fromDeckId: String) throws {
        logManager?.trackEvent(event: Event.deleteFlashcardStart(flashcardId: id))

        do {
            try local.deleteFlashcard(id: id)

            // Update local state
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
            case .loadDecksFail(error: let error), .createDeckFail(error: let error), .updateDeckFail(error: let error), .deleteDeckFail(error: let error), .addFlashcardFail(error: let error), .deleteFlashcardFail(error: let error), .logInFail(error: let error), .remotePushFail(error: let error), .remoteDeleteFail(error: let error):
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
