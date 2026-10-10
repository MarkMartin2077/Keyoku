//
//  QuizManagerTests.swift
//  KeyokuUnitTests
//

// QuizManager is local-first like FlashcardManager: writes land in local storage
// and memory immediately, then push to remote in the background. These tests use
// MockQuizPersistence (in-memory local) and MockRemoteQuizService (in-memory remote
// that keeps what it was sent), plus MockLogService to verify analytics.

import Testing
@testable import Keyoku
import Foundation
import SwiftData

// MARK: - Helpers

/// Builds a QuizManager over in-memory stores. Pass `local`/`remote` in when a test
/// needs to seed them or inspect what was persisted or pushed.
@MainActor
private func makeManager(
    local: MockQuizPersistence? = nil,
    remote: MockRemoteQuizService? = nil
) -> (QuizManager, MockLogService) {
    let mockLog = MockLogService()
    let manager = QuizManager(
        services: MockQuizServices(
            local: local ?? MockQuizPersistence(quizzes: []),
            remote: remote ?? MockRemoteQuizService()
        ),
        logManager: LogManager(services: [mockLog])
    )
    return (manager, mockLog)
}

/// Waits (up to about a second) for fire-and-forget remote tasks to land.
@MainActor
private func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<100 where !condition() {
        try? await Task.sleep(for: .milliseconds(10))
    }
}

private func makeQuiz(id: String = UUID().uuidString, deckId: String, attempts: [QuizAttemptModel] = []) -> QuizModel {
    QuizModel(id: id, deckId: deckId, title: "Quiz \(id)", questions: QuizQuestionModel.mocks, attempts: attempts)
}

// MARK: - Create

@Suite("QuizManager — Create")
@MainActor
struct QuizManagerCreateTests {

    @Test("Creating a quiz adds it to memory and local storage, and tracks events")
    func createQuiz() throws {
        // GIVEN
        let local = MockQuizPersistence(quizzes: [])
        let (manager, mockLog) = makeManager(local: local)

        // WHEN
        let quiz = try manager.createQuiz(deckId: "deck1", title: "Greetings", questions: QuizQuestionModel.mocks)

        // THEN
        #expect(manager.quizzes.map(\.id) == [quiz.id])
        #expect(quiz.deckId == "deck1")
        #expect(quiz.title == "Greetings")
        #expect(quiz.questions.count == QuizQuestionModel.mocks.count)
        #expect(quiz.attempts.isEmpty)
        #expect(quiz.bestScore == nil)
        #expect(try local.getAllQuizzes().quizzes.map(\.id) == [quiz.id])

        // AND
        #expect(mockLog.hasEvent(named: "QuizMan_CreateQuiz_Start"))
        #expect(mockLog.hasEvent(named: "QuizMan_CreateQuiz_Success"))
    }

    @Test("A quiz created while signed in is pushed to remote")
    func createQuizPushesToRemote() async throws {
        // GIVEN — a signed-in manager
        let remote = MockRemoteQuizService()
        let (manager, mockLog) = makeManager(remote: remote)
        await manager.logIn(userId: "user1", existingDeckIds: ["deck1"])

        // WHEN
        let quiz = try manager.createQuiz(deckId: "deck1", title: "Greetings", questions: QuizQuestionModel.mocks)

        // THEN — the background push reaches remote
        await waitUntil { remote.quizzes.contains { $0.id == quiz.id } }
        #expect(remote.quizzes.map(\.id) == [quiz.id])
        #expect(mockLog.hasEvent(named: "QuizMan_RemotePush_Success"))
    }

    @Test("A quiz created while signed out stays local")
    func createQuizSignedOutStaysLocal() async throws {
        let local = MockQuizPersistence(quizzes: [])
        let remote = MockRemoteQuizService()
        let (manager, _) = makeManager(local: local, remote: remote)

        try manager.createQuiz(deckId: "deck1", title: "Offline", questions: QuizQuestionModel.mocks)
        await Task.yield()

        #expect(try local.getAllQuizzes().quizzes.count == 1)
        #expect(remote.quizzes.isEmpty)
    }

    @Test("quizzes(forDeckId:) returns only that deck's quizzes, newest first")
    func quizzesForDeck() throws {
        // GIVEN
        let (manager, _) = makeManager()
        let first = try manager.createQuiz(deckId: "deck1", title: "First", questions: QuizQuestionModel.mocks)
        try manager.createQuiz(deckId: "deck2", title: "Other deck", questions: QuizQuestionModel.mocks)
        let second = try manager.createQuiz(deckId: "deck1", title: "Second", questions: QuizQuestionModel.mocks)

        // WHEN
        let deckQuizzes = manager.quizzes(forDeckId: "deck1")

        // THEN
        #expect(deckQuizzes.map(\.id) == [second.id, first.id])
    }

    @Test("Questions keep their stable ids and three wrong answers")
    func questionsKeepIds() throws {
        let (manager, _) = makeManager()

        let quiz = try manager.createQuiz(deckId: "deck1", title: "Greetings", questions: QuizQuestionModel.mocks)

        #expect(quiz.questions.map(\.id) == QuizQuestionModel.mocks.map(\.id))
        #expect(quiz.questions.allSatisfy { $0.wrongAnswers.count == 3 })
    }
}

// MARK: - Attempts & Best Score

@Suite("QuizManager — Attempts")
@MainActor
struct QuizManagerAttemptTests {

    @Test("Recording an attempt appends it, persists it and tracks events")
    func recordAttempt() throws {
        // GIVEN
        let local = MockQuizPersistence(quizzes: [makeQuiz(id: "quiz1", deckId: "deck1")])
        let (manager, mockLog) = makeManager(local: local)
        manager.loadQuizzes()
        let date = Date(timeIntervalSince1970: 1_000_000)

        // WHEN
        let updated = try manager.recordAttempt(quizId: "quiz1", score: 4, total: 5, date: date)

        // THEN
        #expect(updated.attempts == [QuizAttemptModel(date: date, score: 4, total: 5)])
        #expect(manager.quizzes.first?.attempts.count == 1)
        #expect(try local.getAllQuizzes().quizzes.first?.attempts.count == 1)

        // AND
        #expect(mockLog.hasEvent(named: "QuizMan_RecordAttempt_Start"))
        #expect(mockLog.hasEvent(named: "QuizMan_RecordAttempt_Success"))
    }

    @Test("Recording an attempt rewrites the quiz on remote")
    func recordAttemptRewritesRemote() async throws {
        // GIVEN — a signed-in manager with one synced quiz
        let remote = MockRemoteQuizService(quizzes: [makeQuiz(id: "quiz1", deckId: "deck1")])
        let (manager, _) = makeManager(remote: remote)
        await manager.logIn(userId: "user1", existingDeckIds: ["deck1"])

        // WHEN
        try manager.recordAttempt(quizId: "quiz1", score: 2, total: 5)

        // THEN
        await waitUntil { remote.quizzes.first?.attempts.count == 1 }
        #expect(remote.quizzes.count == 1)
        #expect(remote.quizzes.first?.attempts.first?.score == 2)
    }

    @Test("Recording an attempt for an unknown quiz throws and tracks a fail event")
    func recordAttemptUnknownQuiz() {
        let (manager, mockLog) = makeManager()

        #expect(throws: (any Error).self) {
            try manager.recordAttempt(quizId: "missing", score: 1, total: 5)
        }
        #expect(mockLog.hasEvent(named: "QuizMan_RecordAttempt_Fail"))
    }

    @Test("Best score is nil before any attempt")
    func bestScoreNil() {
        #expect(makeQuiz(deckId: "deck1").bestScore == nil)
    }

    @Test("Best score is the highest score across attempts, not the latest")
    func bestScoreIsMax() throws {
        // GIVEN
        let (manager, _) = makeManager(local: MockQuizPersistence(quizzes: [makeQuiz(id: "quiz1", deckId: "deck1")]))
        manager.loadQuizzes()

        // WHEN
        try manager.recordAttempt(quizId: "quiz1", score: 2, total: 5)
        try manager.recordAttempt(quizId: "quiz1", score: 5, total: 5)
        let latest = try manager.recordAttempt(quizId: "quiz1", score: 3, total: 5)

        // THEN
        #expect(latest.bestScore == 5)
        #expect(manager.quizzes.first?.bestScore == 5)
    }

    @Test("Best score is not stored in the encoded quiz")
    func bestScoreNotStored() throws {
        let quiz = makeQuiz(deckId: "deck1", attempts: [QuizAttemptModel(score: 4, total: 5)])

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(quiz)) as? [String: Any]

        #expect(json?["best_score"] == nil)
        #expect(json?["deck_id"] as? String == "deck1")
    }
}

// MARK: - Deletion

@Suite("QuizManager — Deletion")
@MainActor
struct QuizManagerDeletionTests {

    @Test("Deleting a quiz removes it locally and remotely, and tracks events")
    func deleteQuiz() async throws {
        // GIVEN
        let local = MockQuizPersistence(quizzes: [])
        let remote = MockRemoteQuizService(quizzes: [makeQuiz(id: "quiz1", deckId: "deck1"), makeQuiz(id: "quiz2", deckId: "deck1")])
        let (manager, mockLog) = makeManager(local: local, remote: remote)
        await manager.logIn(userId: "user1", existingDeckIds: ["deck1"])

        // WHEN
        try manager.deleteQuiz(id: "quiz1")

        // THEN
        #expect(manager.quizzes.map(\.id) == ["quiz2"])
        #expect(try local.getAllQuizzes().quizzes.map(\.id) == ["quiz2"])
        await waitUntil { remote.quizzes.count == 1 }
        #expect(remote.quizzes.map(\.id) == ["quiz2"])

        // AND
        #expect(mockLog.hasEvent(named: "QuizMan_DeleteQuiz_Start"))
        #expect(mockLog.hasEvent(named: "QuizMan_DeleteQuiz_Success"))
    }

    @Test("Deleting a deck's quizzes removes only that deck's quizzes, locally and remotely")
    func deleteDeckQuizzes() async throws {
        // GIVEN — two quizzes on deck1, one on deck2
        let local = MockQuizPersistence(quizzes: [])
        let remote = MockRemoteQuizService(quizzes: [
            makeQuiz(id: "quiz1", deckId: "deck1"),
            makeQuiz(id: "quiz2", deckId: "deck1"),
            makeQuiz(id: "quiz3", deckId: "deck2")
        ])
        let (manager, mockLog) = makeManager(local: local, remote: remote)
        await manager.logIn(userId: "user1", existingDeckIds: ["deck1", "deck2"])

        // WHEN
        try manager.deleteQuizzes(deckId: "deck1")

        // THEN — memory and local storage update immediately
        #expect(manager.quizzes.map(\.id) == ["quiz3"])
        #expect(try local.getAllQuizzes().quizzes.map(\.id) == ["quiz3"])

        // AND — the background remote delete catches up
        await waitUntil { remote.quizzes.count == 1 }
        #expect(remote.quizzes.map(\.id) == ["quiz3"])

        // AND
        #expect(mockLog.hasEvent(named: "QuizMan_DeleteDeckQuizzes_Start"))
        #expect(mockLog.hasEvent(named: "QuizMan_DeleteDeckQuizzes_Success"))
        #expect(mockLog.hasEvent(named: "QuizMan_RemoteDeleteDeckQuizzes_Success"))
    }

    @Test("Deleting all quizzes waits for remote and empties every store")
    func deleteAllQuizzes() async throws {
        // GIVEN
        let local = MockQuizPersistence(quizzes: [])
        let remote = MockRemoteQuizService(quizzes: [makeQuiz(id: "quiz1", deckId: "deck1"), makeQuiz(id: "quiz2", deckId: "deck2")])
        let (manager, mockLog) = makeManager(local: local, remote: remote)
        await manager.logIn(userId: "user1", existingDeckIds: ["deck1", "deck2"])

        // WHEN
        try await manager.deleteAllQuizzes()

        // THEN — no waiting needed: the remote delete is awaited
        #expect(manager.quizzes.isEmpty)
        #expect(try local.getAllQuizzes().quizzes.isEmpty)
        #expect(remote.quizzes.isEmpty)

        // AND
        #expect(mockLog.hasEvent(named: "QuizMan_DeleteAllQuizzes_Start"))
        #expect(mockLog.hasEvent(named: "QuizMan_DeleteAllQuizzes_Success"))
    }

    @Test("Deleting all quizzes while signed out keeps them and tracks a fail event")
    func deleteAllQuizzesSignedOut() async throws {
        let (manager, mockLog) = makeManager(local: MockQuizPersistence(quizzes: [makeQuiz(id: "quiz1", deckId: "deck1")]))
        manager.loadQuizzes()

        try await manager.deleteAllQuizzes()

        #expect(manager.quizzes.count == 1)
        #expect(mockLog.hasEvent(named: "QuizMan_DeleteAllQuizzes_Fail"))
    }
}

// MARK: - Auth Lifecycle

@Suite("QuizManager — Auth Lifecycle")
@MainActor
struct QuizManagerLifecycleTests {

    @Test("Logging in downloads remote quizzes into local storage and tracks events")
    func logInSyncsQuizzes() async throws {
        // GIVEN — a quiz that exists only on remote
        let local = MockQuizPersistence(quizzes: [])
        let remote = MockRemoteQuizService(quizzes: [makeQuiz(id: "quiz1", deckId: "deck1")])
        let (manager, mockLog) = makeManager(local: local, remote: remote)

        // WHEN
        await manager.logIn(userId: "user1", existingDeckIds: ["deck1"])

        // THEN
        #expect(manager.quizzes.map(\.id) == ["quiz1"])
        #expect(try local.getAllQuizzes().quizzes.map(\.id) == ["quiz1"])

        // AND
        #expect(mockLog.hasEvent(named: "QuizMan_LogIn_Start"))
        #expect(mockLog.hasEvent(named: "QuizMan_LogIn_Success"))
    }

    @Test("Logging in deletes quizzes whose deck no longer exists, locally and remotely")
    func logInSweepsOrphans() async throws {
        // GIVEN — quiz2 points at a deck deleted on another device
        let quizzes = [makeQuiz(id: "quiz1", deckId: "deck1"), makeQuiz(id: "quiz2", deckId: "deletedDeck")]
        let local = MockQuizPersistence(quizzes: quizzes)
        let remote = MockRemoteQuizService(quizzes: quizzes)
        let (manager, mockLog) = makeManager(local: local, remote: remote)

        // WHEN
        await manager.logIn(userId: "user1", existingDeckIds: ["deck1"])

        // THEN — the orphan is gone locally at once and the other quiz is untouched
        #expect(manager.quizzes.map(\.id) == ["quiz1"])
        #expect(try local.getAllQuizzes().quizzes.map(\.id) == ["quiz1"])

        // AND — the background remote delete catches up
        await waitUntil { remote.quizzes.count == 1 }
        #expect(remote.quizzes.map(\.id) == ["quiz1"])

        // AND — success reports one local delete and one remote delete dispatched
        #expect(mockLog.hasEvent(named: "QuizMan_DeleteOrphans_Start"))
        let success = mockLog.events.first { $0.eventName == "QuizMan_DeleteOrphans_Success" }
        #expect(success?.parameters?["local_deleted_count"] as? Int == 1)
        #expect(success?.parameters?["remote_dispatched_count"] as? Int == 1)
        await waitUntil { mockLog.hasEvent(named: "QuizMan_RemoteDelete_Success") }
        #expect(mockLog.hasEvent(named: "QuizMan_RemoteDelete_Success"))
    }

    @Test("Logging in doesn't wait for the orphans' remote deletes")
    func logInDoesNotWaitForRemoteOrphanDeletes() async throws {
        // GIVEN — remote deletes are slow, like Firestore while offline
        let quizzes = [makeQuiz(id: "quiz1", deckId: "deck1"), makeQuiz(id: "quiz2", deckId: "deletedDeck")]
        let local = MockQuizPersistence(quizzes: quizzes)
        let remote = MockRemoteQuizService(quizzes: quizzes, deleteDelay: .milliseconds(300))
        let (manager, _) = makeManager(local: local, remote: remote)

        // WHEN
        await manager.logIn(userId: "user1", existingDeckIds: ["deck1"])

        // THEN — logIn returned with the orphan gone locally while its remote delete is still running
        #expect(try local.getAllQuizzes().quizzes.map(\.id) == ["quiz1"])
        #expect(remote.quizzes.count == 2)

        // AND — the remote delete finishes in the background
        await waitUntil { remote.quizzes.count == 1 }
        #expect(remote.quizzes.map(\.id) == ["quiz1"])
    }

    @Test("Logging in without a trusted deck list keeps every quiz")
    func logInWithoutDeckListSkipsSweep() async throws {
        let remote = MockRemoteQuizService(quizzes: [makeQuiz(id: "quiz1", deckId: "deck1"), makeQuiz(id: "quiz2", deckId: "unknownDeck")])
        let (manager, mockLog) = makeManager(remote: remote)

        await manager.logIn(userId: "user1", existingDeckIds: nil)

        #expect(manager.quizzes.count == 2)
        #expect(remote.quizzes.count == 2)
        #expect(!mockLog.hasEvent(named: "QuizMan_DeleteOrphans_Start"))
    }

    @Test("Signing out clears memory but keeps local storage")
    func signOutKeepsLocal() async throws {
        // GIVEN
        let local = MockQuizPersistence(quizzes: [])
        let remote = MockRemoteQuizService(quizzes: [makeQuiz(id: "quiz1", deckId: "deck1")])
        let (manager, mockLog) = makeManager(local: local, remote: remote)
        await manager.logIn(userId: "user1", existingDeckIds: ["deck1"])

        // WHEN
        manager.signOut()

        // THEN
        #expect(manager.quizzes.isEmpty)
        #expect(try local.getAllQuizzes().quizzes.count == 1)
        #expect(mockLog.hasEvent(named: "QuizMan_SignOut"))
    }
}

// MARK: - Corrupt Rows

@Suite("QuizManager — Corrupt Rows")
@MainActor
struct QuizManagerCorruptRowTests {

    @Test("A quiz row that can't be decoded is skipped and the rest still load")
    func swiftDataSkipsCorruptRow() throws {
        // GIVEN — an in-memory store with one valid row and one with unreadable questions
        let container = try ModelContainer(
            for: QuizEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let persistence = SwiftDataQuizPersistence(container: container)
        try persistence.saveQuiz(makeQuiz(id: "quiz1", deckId: "deck1"))
        container.mainContext.insert(QuizEntity(
            id: "corrupt",
            deckId: "deck1",
            title: "Corrupt",
            createdAt: .now,
            questionsData: Data("not json".utf8),
            attemptsData: Data("[]".utf8)
        ))
        try container.mainContext.save()

        // WHEN
        let result = try persistence.getAllQuizzes()

        // THEN
        #expect(result.quizzes.map(\.id) == ["quiz1"])
        #expect(result.skippedCount == 1)
    }

    @Test("Loading quizzes tracks a warning when rows were skipped")
    func loadQuizzesWarnsAboutSkippedRows() {
        // GIVEN — local storage reports one unreadable row next to a valid quiz
        let local = MockQuizPersistence(quizzes: [makeQuiz(id: "quiz1", deckId: "deck1")], skippedCount: 1)
        let (manager, mockLog) = makeManager(local: local)

        // WHEN
        manager.loadQuizzes()

        // THEN
        #expect(manager.quizzes.map(\.id) == ["quiz1"])
        let warning = mockLog.events.first { $0.eventName == "QuizMan_LoadQuizzes_SkippedCorrupt" }
        #expect(warning?.type == .warning)
        #expect(warning?.parameters?["skipped_count"] as? Int == 1)
        #expect(mockLog.hasEvent(named: "QuizMan_LoadQuizzes_Success"))
    }
}

// MARK: - Migration

@Suite("QuizManager — Migration")
@MainActor
struct QuizManagerMigrationTests {

    @Test("Migrating pushes the anonymous user's quizzes to the new account and keeps them locally")
    func migrateQuizzes() async throws {
        // GIVEN — quizzes made while anonymous, now signed in to a new account with nothing on remote
        let local = MockQuizPersistence(quizzes: [
            makeQuiz(id: "quiz1", deckId: "deck1"),
            makeQuiz(id: "quiz2", deckId: "otherDeck")
        ])
        let remote = MockRemoteQuizService()
        let (manager, mockLog) = makeManager(local: local, remote: remote)
        await manager.logIn(userId: "newAccount", existingDeckIds: nil)

        // WHEN — only deck1 is being migrated
        manager.migrateQuizzes(deckIds: ["deck1"])

        // THEN — deck1's quiz reaches the new account's remote
        await waitUntil { remote.quizzes.contains { $0.id == "quiz1" } }
        #expect(remote.quizzes.map(\.id) == ["quiz1"])

        // AND — both quizzes stay local and in memory
        #expect(Set(try local.getAllQuizzes().quizzes.map(\.id)) == ["quiz1", "quiz2"])
        #expect(Set(manager.quizzes.map(\.id)) == ["quiz1", "quiz2"])

        // AND
        #expect(mockLog.hasEvent(named: "QuizMan_MigrateQuizzes_Start"))
        #expect(mockLog.hasEvent(named: "QuizMan_MigrateQuizzes_Success"))
    }
}
