//
//  FlashcardManagerTests.swift
//  KeyokuUnitTests
//
//

import Testing
@testable import Keyoku
import Foundation

// MARK: - FlashcardManager — Deck CRUD

// These tests cover the core CRUD operations for decks and flashcards.
// FlashcardManager uses a local-first architecture — writes go to local
// storage immediately, then push to remote in the background.
//
// We use MockFlashcardServices which provides:
//   - MockDeckPersistence (in-memory local storage)
//   - MockRemoteDeckService (no-op remote)
//
// This lets us test the manager's logic without touching real databases.

@Suite("FlashcardManager — Deck CRUD")
@MainActor
struct FlashcardManagerDeckTests {

    // -------------------------------------------------------
    // HELPER — creates a FlashcardManager with an empty local store
    // -------------------------------------------------------
    // Starting empty makes tests predictable. Each test creates
    // exactly the data it needs.

    // -------------------------------------------------------
    // HELPER — creates a FlashcardManager with a MockLogService
    // -------------------------------------------------------
    // The mockLog captures every analytics event so we can
    // verify tracking alongside state changes.

    private func makeManager(
        decks: [DeckModel] = [],
        mockLog: MockLogService = MockLogService()
    ) -> (FlashcardManager, MockLogService) {
        let logManager = LogManager(services: [mockLog])
        let manager = FlashcardManager(services: MockFlashcardServices(decks: decks), logManager: logManager)
        return (manager, mockLog)
    }

    // -------------------------------------------------------
    // TEST 1: Manager starts with no decks when given empty data
    // -------------------------------------------------------

    @Test("Decks array is empty when initialized with no data")
    func decksEmptyOnInit() {
        // GIVEN — a manager with no decks
        let (manager, _) = makeManager()

        // THEN — decks should be empty
        #expect(manager.decks.isEmpty)
    }

    // -------------------------------------------------------
    // TEST 2: loadDecks populates from local storage
    // -------------------------------------------------------
    // MockFlashcardServices seeds MockDeckPersistence with the
    // decks we pass in. loadDecks() reads from local storage.

    @Test("loadDecks loads decks from local storage and tracks events")
    func loadDecksPopulatesArray() {
        // GIVEN — a manager seeded with mock decks
        let (manager, mockLog) = makeManager(decks: DeckModel.mocks)

        // WHEN — we load decks
        manager.loadDecks()

        // THEN — decks should contain the seeded data
        #expect(manager.decks.count == DeckModel.mocks.count)

        // AND — load events should have been tracked
        #expect(mockLog.hasEvent(named: "FlashcardMan_LoadDecks_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardMan_LoadDecks_Success"))
    }

    // -------------------------------------------------------
    // TEST 3: Create an empty deck
    // -------------------------------------------------------
    // createDeck(name:...) without flashcards creates a deck
    // with zero cards.

    @Test("Creating an empty deck adds it and tracks events")
    func createEmptyDeck() throws {
        // GIVEN — an empty manager
        let (manager, mockLog) = makeManager()
        #expect(manager.decks.isEmpty)

        // WHEN — we create a deck
        try manager.createDeck(name: "Test Deck", color: .blue, sourceText: "Some source")

        // THEN — decks should have one entry
        #expect(manager.decks.count == 1)
        #expect(manager.decks[0].name == "Test Deck")
        #expect(manager.decks[0].color == .blue)
        #expect(manager.decks[0].flashcards.isEmpty)

        // AND — create events should have been tracked
        #expect(mockLog.hasEvent(named: "FlashcardMan_CreateDeck_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardMan_CreateDeck_Success"))
    }

    // -------------------------------------------------------
    // TEST 4: Create a deck with flashcards
    // -------------------------------------------------------
    // When creating with flashcards, each card's deckId is
    // remapped to match the new deck's ID.

    @Test("Creating a deck with flashcards includes them and remaps deckId")
    func createDeckWithFlashcards() throws {
        // GIVEN — an empty manager and some flashcards
        let (manager, _) = makeManager()
        let cards = [
            FlashcardModel(question: "Q1", answer: "A1"),
            FlashcardModel(question: "Q2", answer: "A2"),
            FlashcardModel(question: "Q3", answer: "A3")
        ]

        // WHEN — we create a deck with those flashcards
        try manager.createDeck(
            name: "Generated Deck",
            color: .orange,
            sourceText: "Source material",
            flashcards: cards
        )

        // THEN — deck should have 3 flashcards
        #expect(manager.decks.count == 1)
        let deck = manager.decks[0]
        #expect(deck.flashcards.count == 3)

        // AND — every flashcard's deckId should match the parent deck
        for card in deck.flashcards {
            #expect(card.deckId == deck.deckId)
        }
    }

    // -------------------------------------------------------
    // TEST 5: New decks appear at index 0 (most recent first)
    // -------------------------------------------------------

    @Test("Newly created decks are inserted at the front of the array")
    func newDeckInsertedAtFront() throws {
        // GIVEN — a manager with one existing deck
        let (manager, _) = makeManager()
        try manager.createDeck(name: "First", sourceText: "text")

        // WHEN — we create a second deck
        try manager.createDeck(name: "Second", sourceText: "text")

        // THEN — the newest deck should be at index 0
        #expect(manager.decks.count == 2)
        #expect(manager.decks[0].name == "Second")
        #expect(manager.decks[1].name == "First")
    }

    // -------------------------------------------------------
    // TEST 6: getDeck returns correct deck by ID
    // -------------------------------------------------------

    @Test("getDeck returns the correct deck by ID")
    func getDeckById() throws {
        // GIVEN — a manager with a created deck
        let (manager, _) = makeManager()
        try manager.createDeck(name: "Find Me", sourceText: "text")
        let deckId = manager.decks[0].deckId

        // WHEN — we look up the deck by ID
        let result = manager.getDeck(id: deckId)

        // THEN — it should return the correct deck
        #expect(result != nil)
        #expect(result?.name == "Find Me")
    }

    // -------------------------------------------------------
    // TEST 7: getDeck returns nil for unknown ID
    // -------------------------------------------------------

    @Test("getDeck returns nil for non-existent ID")
    func getDeckReturnsNilForUnknownId() {
        // GIVEN — an empty manager
        let (manager, _) = makeManager()

        // WHEN — we look up a non-existent ID
        let result = manager.getDeck(id: "does-not-exist")

        // THEN — result should be nil
        #expect(result == nil)
    }

    // -------------------------------------------------------
    // TEST 8: Update a deck's name and color
    // -------------------------------------------------------
    // DeckModel is a value type with let fields, so updating
    // means reconstructing with the same ID and new values.

    @Test("Updating a deck changes its name and color and tracks events")
    func updateDeckNameAndColor() throws {
        // GIVEN — a manager with a deck
        let (manager, mockLog) = makeManager()
        try manager.createDeck(name: "Original", color: .blue, sourceText: "text")
        let original = manager.decks[0]

        // WHEN — we update the deck with a new name and color
        let updated = DeckModel(
            deckId: original.deckId,
            name: "Renamed",
            color: .green,
            sourceText: original.sourceText,
            createdAt: original.createdAt,
            flashcards: original.flashcards
        )
        try manager.updateDeck(updated)

        // THEN — the deck should reflect the changes
        #expect(manager.decks.count == 1)
        #expect(manager.decks[0].name == "Renamed")
        #expect(manager.decks[0].color == .green)
        #expect(manager.decks[0].deckId == original.deckId)

        // AND — update events should have been tracked
        #expect(mockLog.hasEvent(named: "FlashcardMan_UpdateDeck_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardMan_UpdateDeck_Success"))
    }

    // -------------------------------------------------------
    // TEST 9: Delete a deck removes it from the array
    // -------------------------------------------------------

    @Test("Deleting a deck removes it and tracks events")
    func deleteDeckRemovesIt() throws {
        // GIVEN — a manager with two decks
        let (manager, mockLog) = makeManager()
        try manager.createDeck(name: "Keep", sourceText: "text")
        try manager.createDeck(name: "Delete Me", sourceText: "text")
        let deleteId = manager.decks.first(where: { $0.name == "Delete Me" })!.deckId

        // WHEN — we delete one deck
        try manager.deleteDeck(id: deleteId)

        // THEN — only one deck remains and it's the correct one
        #expect(manager.decks.count == 1)
        #expect(manager.decks[0].name == "Keep")

        // AND — delete events should have been tracked
        #expect(mockLog.hasEvent(named: "FlashcardMan_DeleteDeck_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardMan_DeleteDeck_Success"))
    }

    // -------------------------------------------------------
    // TEST 10: Delete all decks clears everything
    // -------------------------------------------------------
    // deleteAllDecks is async because it deletes from remote too.

    @Test("Deleting all decks clears the array and tracks events")
    func deleteAllDecks() async throws {
        // GIVEN — a manager with decks, logged in
        let (manager, mockLog) = makeManager()
        try manager.createDeck(name: "Deck A", sourceText: "text")
        try manager.createDeck(name: "Deck B", sourceText: "text")
        try await manager.logIn(userId: "test-user")

        // WHEN — we delete all decks
        try await manager.deleteAllDecks()

        // THEN — decks should be empty
        #expect(manager.decks.isEmpty)

        // AND — delete-all events should have been tracked
        #expect(mockLog.hasEvent(named: "FlashcardMan_DeleteAllDecks_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardMan_DeleteAllDecks_Success"))
    }
}

// MARK: - FlashcardManager — Flashcard CRUD

@Suite("FlashcardManager — Flashcard CRUD")
@MainActor
struct FlashcardManagerFlashcardTests {

    private func makeManager(
        decks: [DeckModel] = [],
        mockLog: MockLogService = MockLogService()
    ) -> (FlashcardManager, MockLogService) {
        let logManager = LogManager(services: [mockLog])
        let manager = FlashcardManager(services: MockFlashcardServices(decks: decks), logManager: logManager)
        return (manager, mockLog)
    }

    // -------------------------------------------------------
    // TEST 1: Add a flashcard to a deck
    // -------------------------------------------------------
    // addFlashcard reconstructs the entire deck with the new
    // card appended to the flashcards array.

    @Test("Adding a flashcard increases the deck's card count and tracks events")
    func addFlashcardToDeck() throws {
        // GIVEN — a manager with an empty deck
        let (manager, mockLog) = makeManager()
        try manager.createDeck(name: "Study Deck", sourceText: "text")
        let deckId = manager.decks[0].deckId
        #expect(manager.decks[0].flashcards.isEmpty)

        // WHEN — we add a flashcard
        try manager.addFlashcard(question: "What is 2+2?", answer: "4", toDeckId: deckId)

        // THEN — the deck should have 1 flashcard
        let deck = manager.getDeck(id: deckId)
        #expect(deck?.flashcards.count == 1)
        #expect(deck?.flashcards[0].question == "What is 2+2?")
        #expect(deck?.flashcards[0].answer == "4")

        // AND — add-flashcard events should have been tracked
        #expect(mockLog.hasEvent(named: "FlashcardMan_AddFlashcard_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardMan_AddFlashcard_Success"))
    }

    // -------------------------------------------------------
    // TEST 2: Add multiple flashcards
    // -------------------------------------------------------

    @Test("Adding multiple flashcards accumulates correctly")
    func addMultipleFlashcards() throws {
        // GIVEN — a manager with an empty deck
        let (manager, _) = makeManager()
        try manager.createDeck(name: "Multi Card Deck", sourceText: "text")
        let deckId = manager.decks[0].deckId

        // WHEN — we add 3 flashcards
        try manager.addFlashcard(question: "Q1", answer: "A1", toDeckId: deckId)
        try manager.addFlashcard(question: "Q2", answer: "A2", toDeckId: deckId)
        try manager.addFlashcard(question: "Q3", answer: "A3", toDeckId: deckId)

        // THEN — the deck should have 3 flashcards in order
        let deck = manager.getDeck(id: deckId)
        #expect(deck?.flashcards.count == 3)
        #expect(deck?.flashcards[0].question == "Q1")
        #expect(deck?.flashcards[2].question == "Q3")
    }

    // -------------------------------------------------------
    // TEST 3: Flashcard gets the correct deckId
    // -------------------------------------------------------

    @Test("Added flashcard has correct deckId")
    func flashcardHasCorrectDeckId() throws {
        // GIVEN — a manager with a deck
        let (manager, _) = makeManager()
        try manager.createDeck(name: "Deck", sourceText: "text")
        let deckId = manager.decks[0].deckId

        // WHEN — we add a flashcard
        try manager.addFlashcard(question: "Q", answer: "A", toDeckId: deckId)

        // THEN — the flashcard's deckId should match the parent deck
        let card = manager.getDeck(id: deckId)?.flashcards[0]
        #expect(card?.deckId == deckId)
    }

    // -------------------------------------------------------
    // TEST 4: Delete a flashcard from a deck
    // -------------------------------------------------------
    // deleteFlashcard reconstructs the deck without the card.

    @Test("Deleting a flashcard removes it and tracks events")
    func deleteFlashcard() throws {
        // GIVEN — a deck with 2 flashcards
        let (manager, mockLog) = makeManager()
        try manager.createDeck(name: "Deck", sourceText: "text")
        let deckId = manager.decks[0].deckId
        try manager.addFlashcard(question: "Keep", answer: "A1", toDeckId: deckId)
        try manager.addFlashcard(question: "Delete", answer: "A2", toDeckId: deckId)
        let deleteCardId = manager.getDeck(id: deckId)!.flashcards
            .first(where: { $0.question == "Delete" })!.flashcardId

        // WHEN — we delete one flashcard
        try manager.deleteFlashcard(id: deleteCardId, fromDeckId: deckId)

        // THEN — only 1 flashcard remains
        let deck = manager.getDeck(id: deckId)
        #expect(deck?.flashcards.count == 1)
        #expect(deck?.flashcards[0].question == "Keep")

        // AND — delete-flashcard events should have been tracked
        #expect(mockLog.hasEvent(named: "FlashcardMan_DeleteFlashcard_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardMan_DeleteFlashcard_Success"))
    }

    // -------------------------------------------------------
    // TEST 5: Deleting a flashcard doesn't affect other decks
    // -------------------------------------------------------

    @Test("Deleting a flashcard from one deck doesn't affect other decks")
    func deleteFlashcardIsolated() throws {
        // GIVEN — two decks, each with a flashcard
        let (manager, _) = makeManager()
        try manager.createDeck(name: "Deck A", sourceText: "text")
        try manager.createDeck(name: "Deck B", sourceText: "text")
        let deckAId = manager.decks.first(where: { $0.name == "Deck A" })!.deckId
        let deckBId = manager.decks.first(where: { $0.name == "Deck B" })!.deckId
        try manager.addFlashcard(question: "A-Q1", answer: "A-A1", toDeckId: deckAId)
        try manager.addFlashcard(question: "B-Q1", answer: "B-A1", toDeckId: deckBId)

        // WHEN — we delete the flashcard from Deck A
        let cardToDelete = manager.getDeck(id: deckAId)!.flashcards[0].flashcardId
        try manager.deleteFlashcard(id: cardToDelete, fromDeckId: deckAId)

        // THEN — Deck A is empty but Deck B still has its card
        #expect(manager.getDeck(id: deckAId)?.flashcards.count == 0)
        #expect(manager.getDeck(id: deckBId)?.flashcards.count == 1)
    }

    // -------------------------------------------------------
    // TEST 6: Each flashcard gets a unique ID
    // -------------------------------------------------------

    @Test("Each flashcard gets a unique ID")
    func flashcardsHaveUniqueIds() throws {
        // GIVEN — a deck with 3 flashcards added
        let (manager, _) = makeManager()
        try manager.createDeck(name: "Deck", sourceText: "text")
        let deckId = manager.decks[0].deckId
        try manager.addFlashcard(question: "Q1", answer: "A1", toDeckId: deckId)
        try manager.addFlashcard(question: "Q2", answer: "A2", toDeckId: deckId)
        try manager.addFlashcard(question: "Q3", answer: "A3", toDeckId: deckId)

        // THEN — all flashcard IDs should be unique
        let ids = manager.getDeck(id: deckId)!.flashcards.map { $0.flashcardId }
        #expect(Set(ids).count == ids.count)
    }
}

// MARK: - FlashcardManager — Auth Lifecycle

@Suite("FlashcardManager — Auth Lifecycle")
@MainActor
struct FlashcardManagerAuthTests {

    // -------------------------------------------------------
    // TEST 1: Login syncs remote decks to local
    // -------------------------------------------------------
    // On login, remote decks are fetched and merged into local.
    // MockRemoteDeckService returns whatever decks we seed it with.

    @Test("Login loads remote decks into memory and tracks events")
    func loginSyncsDecks() async throws {
        // GIVEN — a manager with mock remote decks
        let mockDecks = DeckModel.mocks
        let mockLog = MockLogService()
        let logManager = LogManager(services: [mockLog])
        let manager = FlashcardManager(services: MockFlashcardServices(decks: mockDecks), logManager: logManager)

        // WHEN — user logs in
        try await manager.logIn(userId: "user123")

        // THEN — decks should be populated
        #expect(!manager.decks.isEmpty)
        #expect(manager.decks.count == mockDecks.count)

        // AND — login events should have been tracked
        #expect(mockLog.hasEvent(named: "FlashcardMan_LogIn_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardMan_LogIn_Success"))
    }

    // -------------------------------------------------------
    // TEST 2: Sign out clears decks
    // -------------------------------------------------------

    @Test("Sign out clears all in-memory decks and tracks event")
    func signOutClearsDecks() async throws {
        // GIVEN — a logged-in manager with decks
        let mockLog = MockLogService()
        let logManager = LogManager(services: [mockLog])
        let manager = FlashcardManager(services: MockFlashcardServices(decks: DeckModel.mocks), logManager: logManager)
        try await manager.logIn(userId: "user123")
        #expect(!manager.decks.isEmpty)

        // WHEN — user signs out
        manager.signOut()

        // THEN — decks should be empty
        #expect(manager.decks.isEmpty)

        // AND — sign-out event should have been tracked
        #expect(mockLog.hasEvent(named: "FlashcardMan_SignOut"))
    }

    // -------------------------------------------------------
    // TEST 3: Sign out doesn't delete local data
    // -------------------------------------------------------
    // After signing out, logging back in should recover decks
    // from local storage (since MockDeckPersistence retains them).

    @Test("Login after sign out recovers decks from local storage")
    func loginAfterSignOutRecoversDecks() async throws {
        // GIVEN — a manager that logged in and signed out
        let mockLog = MockLogService()
        let logManager = LogManager(services: [mockLog])
        let manager = FlashcardManager(services: MockFlashcardServices(decks: DeckModel.mocks), logManager: logManager)
        try await manager.logIn(userId: "user123")
        let deckCount = manager.decks.count
        manager.signOut()
        #expect(manager.decks.isEmpty)

        // WHEN — user logs in again
        try await manager.logIn(userId: "user123")

        // THEN — decks should be recovered
        #expect(manager.decks.count == deckCount)
    }

    // -------------------------------------------------------
    // TEST 4: Full lifecycle: login → create → sign out → login
    // -------------------------------------------------------

    @Test("Full lifecycle: create deck persists across sign-out/sign-in")
    func fullLifecycle() async throws {
        // GIVEN — a manager starting empty
        let mockLog = MockLogService()
        let logManager = LogManager(services: [mockLog])
        let manager = FlashcardManager(services: MockFlashcardServices(decks: []), logManager: logManager)
        try await manager.logIn(userId: "user123")
        #expect(manager.decks.isEmpty)

        // WHEN — we create a deck and sign out
        try manager.createDeck(name: "Persistent Deck", sourceText: "text")
        #expect(manager.decks.count == 1)
        manager.signOut()
        #expect(manager.decks.isEmpty)

        // AND — sign back in
        try await manager.logIn(userId: "user123")

        // THEN — the deck should still be there (loaded from local)
        #expect(manager.decks.count == 1)
        #expect(manager.decks[0].name == "Persistent Deck")
    }
}

// MARK: - DeckModel & FlashcardModel Tests

// These test the data models themselves — making sure
// mock data is correct and model properties work as expected.

@Suite("DeckModel & FlashcardModel")
@MainActor
struct ModelTests {

    // -------------------------------------------------------
    // TEST 1: DeckModel mock has expected properties
    // -------------------------------------------------------

    @Test("DeckModel mock has correct name and color")
    func deckModelMockProperties() {
        // GIVEN — the first mock deck
        let deck = DeckModel.mock

        // THEN — it should have the expected values
        #expect(deck.deckId == "deck1")
        #expect(deck.name == "Spanish Essentials")
        #expect(deck.color == .orange)
        #expect(!deck.flashcards.isEmpty)
    }

    // -------------------------------------------------------
    // TEST 2: Mock decks have associated flashcards
    // -------------------------------------------------------

    @Test("Each mock deck has flashcards with matching deckId")
    func mockDecksHaveMatchingFlashcards() {
        // GIVEN — all mock decks
        let decks = DeckModel.mocks

        // THEN — each deck's flashcards should reference the correct deckId
        for deck in decks {
            for card in deck.flashcards {
                #expect(card.deckId == deck.deckId)
            }
        }
    }

    // -------------------------------------------------------
    // TEST 3: FlashcardModel ID maps to flashcardId
    // -------------------------------------------------------

    @Test("FlashcardModel.id returns flashcardId")
    func flashcardIdMapping() {
        // GIVEN — a flashcard
        let card = FlashcardModel(flashcardId: "card-123", question: "Q", answer: "A")

        // THEN — id and flashcardId should be the same
        #expect(card.id == "card-123")
        #expect(card.id == card.flashcardId)
    }

    // -------------------------------------------------------
    // TEST 4: DeckModel ID maps to deckId
    // -------------------------------------------------------

    @Test("DeckModel.id returns deckId")
    func deckIdMapping() {
        // GIVEN — a deck
        let deck = DeckModel(deckId: "deck-abc", name: "Test", sourceText: "text")

        // THEN — id and deckId should be the same
        #expect(deck.id == "deck-abc")
        #expect(deck.id == deck.deckId)
    }

    // -------------------------------------------------------
    // TEST 5: DeckColor has all expected cases
    // -------------------------------------------------------

    @Test("DeckColor has 12 cases")
    func deckColorCases() {
        // THEN — there should be 12 color options
        #expect(DeckColor.allCases.count == 12)
    }

    // -------------------------------------------------------
    // TEST 6: DeckModel with no image returns nil URL
    // -------------------------------------------------------

    @Test("DeckModel with no image has nil displayImageUrlString")
    func deckNoImageReturnsNil() {
        // GIVEN — a deck without a cover image
        let deck = DeckModel(name: "No Image", sourceText: "text")

        // THEN — image-related properties should be nil
        #expect(deck.imageUrl == nil)
        #expect(deck.displayImageUrlString == nil)
    }

    // -------------------------------------------------------
    // TEST 7: DeckModel with HTTP image returns it directly
    // -------------------------------------------------------

    @Test("DeckModel with HTTP image URL returns it as displayImageUrlString")
    func deckHttpImageUrl() {
        // GIVEN — a deck with an HTTP image URL
        let deck = DeckModel(name: "Remote Image", imageUrl: "https://example.com/image.jpg", sourceText: "text")

        // THEN — displayImageUrlString should return the URL as-is
        #expect(deck.displayImageUrlString == "https://example.com/image.jpg")
    }

    // -------------------------------------------------------
    // TEST 8: FlashcardModel eventParameters includes all fields
    // -------------------------------------------------------

    @Test("FlashcardModel eventParameters contains expected keys")
    func flashcardEventParameters() {
        // GIVEN — a flashcard with all fields
        let card = FlashcardModel(flashcardId: "fc1", question: "Q", answer: "A", deckId: "d1")

        // THEN — eventParameters should include all fields
        let params = card.eventParameters
        #expect(params["flashcard_flashcard_id"] as? String == "fc1")
        #expect(params["flashcard_question"] as? String == "Q")
        #expect(params["flashcard_answer"] as? String == "A")
        #expect(params["flashcard_deck_id"] as? String == "d1")
    }
}
