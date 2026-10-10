//
//  QuizManager.swift
//  Keyoku
//

import SwiftUI

/// Manages quizzes and quiz attempts with the same local-first design as `FlashcardManager`.
///
/// **Data Flow:**
/// 1. Writes go to local storage first (synchronous, immediate)
/// 2. The in-memory `quizzes` array is updated
/// 3. A fire-and-forget `Task` pushes the change to the remote service
///
/// **Storage (ADR 0003):** quizzes live flat beside decks and point at them by `deckId`.
/// Nothing cascades when a deck is deleted, so callers delete a deck's quizzes
/// explicitly and `logIn` sweeps away quizzes whose deck no longer exists.
@MainActor
@Observable
class QuizManager {

    private let local: QuizService
    private let remote: RemoteQuizService
    private let logManager: LogManager?
    private var userId: String?

    /// Every quiz loaded from local storage, newest first.
    private(set) var quizzes: [QuizModel] = []

    init(services: QuizServices, logManager: LogManager? = nil) {
        self.local = services.local
        self.remote = services.remote
        self.logManager = logManager
    }

    // MARK: - Auth Lifecycle

    /// Downloads every remote quiz in one query, merges it into local storage and loads memory.
    /// Falls back to local storage if the remote fetch fails.
    ///
    /// Must run after decks have synced. When `existingDeckIds` is given, every quiz whose
    /// deck is not in it is deleted locally, and remotely in the background. Pass `nil` when
    /// the deck list can't be trusted (for example, the deck sync failed) to skip that cleanup.
    func logIn(userId: String, existingDeckIds: Set<String>?) async {
        self.userId = userId
        logManager?.trackEvent(event: Event.logInStart(userId: userId))

        do {
            let remoteQuizzes = try await remote.getAllQuizzes(userId: userId)
            for quiz in remoteQuizzes {
                try? local.saveQuiz(quiz)
            }
            loadQuizzes()
            logManager?.trackEvent(event: Event.logInSuccess(userId: userId, count: quizzes.count))
        } catch {
            logManager?.trackEvent(event: Event.logInFail(error: error))
            loadQuizzes()
        }

        if let existingDeckIds {
            deleteOrphanedQuizzes(existingDeckIds: existingDeckIds)
        }
    }

    /// Clears the userId and in-memory quizzes. Local storage is kept.
    func signOut() {
        logManager?.trackEvent(event: Event.signOut)
        userId = nil
        quizzes = []
    }

    /// Deletes every quiz remotely and locally, waiting for the remote deletes.
    /// Must be called BEFORE auth is revoked so the remote deletes are allowed.
    func deleteAllQuizzes() async throws {
        logManager?.trackEvent(event: Event.deleteAllQuizzesStart)

        guard let userId else {
            logManager?.trackEvent(event: Event.deleteAllQuizzesFail(error: AppError("No userId for deleteAllQuizzes")))
            return
        }

        do {
            try await remote.deleteAllQuizzes(userId: userId)
        } catch {
            logManager?.trackEvent(event: Event.deleteAllQuizzesFail(error: error))
            throw error
        }

        for quiz in quizzes {
            try? local.deleteQuiz(id: quiz.id)
        }
        quizzes = []
        logManager?.trackEvent(event: Event.deleteAllQuizzesSuccess)
    }

    // MARK: - Reads

    /// Reloads all quizzes from local storage into memory.
    /// Rows that can't be decoded are skipped with a warning so the rest still load.
    /// Errors are logged and leave the array unchanged.
    func loadQuizzes() {
        logManager?.trackEvent(event: Event.loadQuizzesStart)

        do {
            let result = try local.getAllQuizzes()
            quizzes = result.quizzes
            if result.skippedCount > 0 {
                logManager?.trackEvent(event: Event.loadQuizzesSkippedCorrupt(count: result.skippedCount))
            }
            logManager?.trackEvent(event: Event.loadQuizzesSuccess(count: quizzes.count))
        } catch {
            logManager?.trackEvent(event: Event.loadQuizzesFail(error: error))
        }
    }

    /// The deck's quizzes, newest first. A pure in-memory read, so it tracks no event
    /// (like `FlashcardManager.getDeck`) to avoid an analytics event on every render.
    func quizzes(forDeckId deckId: String) -> [QuizModel] {
        quizzes
            .filter { $0.deckId == deckId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Writes

    @discardableResult
    func createQuiz(deckId: String, title: String, questions: [QuizQuestionModel]) throws -> QuizModel {
        logManager?.trackEvent(event: Event.createQuizStart(deckId: deckId))

        let quiz = QuizModel(deckId: deckId, title: title, questions: questions)

        do {
            try local.saveQuiz(quiz)
            quizzes.insert(quiz, at: 0)
            logManager?.trackEvent(event: Event.createQuizSuccess(quiz: quiz))
            pushQuizToRemote(quiz)
            return quiz
        } catch {
            logManager?.trackEvent(event: Event.createQuizFail(error: error))
            throw error
        }
    }

    /// Appends an attempt to the quiz and rewrites the whole quiz locally and remotely.
    @discardableResult
    func recordAttempt(quizId: String, score: Int, total: Int, date: Date = .now) throws -> QuizModel {
        logManager?.trackEvent(event: Event.recordAttemptStart(quizId: quizId))

        do {
            guard let index = quizzes.firstIndex(where: { $0.id == quizId }) else {
                throw AppError("Quiz not found")
            }
            let updatedQuiz = quizzes[index].appendingAttempt(QuizAttemptModel(date: date, score: score, total: total))
            try local.saveQuiz(updatedQuiz)
            quizzes[index] = updatedQuiz
            logManager?.trackEvent(event: Event.recordAttemptSuccess(quiz: updatedQuiz))
            pushQuizToRemote(updatedQuiz)
            return updatedQuiz
        } catch {
            logManager?.trackEvent(event: Event.recordAttemptFail(error: error))
            throw error
        }
    }

    func deleteQuiz(id: String) throws {
        logManager?.trackEvent(event: Event.deleteQuizStart(quizId: id))

        do {
            try local.deleteQuiz(id: id)
            quizzes.removeAll { $0.id == id }
            logManager?.trackEvent(event: Event.deleteQuizSuccess(quizId: id))
            deleteQuizFromRemote(quizId: id)
        } catch {
            logManager?.trackEvent(event: Event.deleteQuizFail(error: error))
            throw error
        }
    }

    /// Deletes a deck's quizzes locally now, and remotely in the background
    /// with a single `deck_id` query.
    func deleteQuizzes(deckId: String) throws {
        logManager?.trackEvent(event: Event.deleteDeckQuizzesStart(deckId: deckId))

        do {
            try local.deleteQuizzes(deckId: deckId)
            quizzes.removeAll { $0.deckId == deckId }
            logManager?.trackEvent(event: Event.deleteDeckQuizzesSuccess(deckId: deckId))
            deleteDeckQuizzesFromRemote(deckId: deckId)
        } catch {
            logManager?.trackEvent(event: Event.deleteDeckQuizzesFail(error: error))
            throw error
        }
    }

    // MARK: - Migration

    /// Pushes the given decks' local quizzes to the current user's remote path.
    /// Used after an anonymous user links an account, alongside `FlashcardManager.migrateDecks`.
    func migrateQuizzes(deckIds: Set<String>) {
        let quizzesToMigrate = quizzes.filter { deckIds.contains($0.deckId) }
        logManager?.trackEvent(event: Event.migrateQuizzesStart(count: quizzesToMigrate.count))

        for quiz in quizzesToMigrate {
            pushQuizToRemote(quiz)
        }

        logManager?.trackEvent(event: Event.migrateQuizzesSuccess(count: quizzesToMigrate.count))
    }

    // MARK: - Orphan Cleanup

    /// Deletes every loaded quiz whose deck is not in `existingDeckIds` locally now, and
    /// remotely in the background so an offline Firestore can't stall `logIn`.
    /// The background deletes log their own success or failure.
    private func deleteOrphanedQuizzes(existingDeckIds: Set<String>) {
        let orphanedQuizzes = quizzes.filter { !existingDeckIds.contains($0.deckId) }
        guard !orphanedQuizzes.isEmpty else { return }

        logManager?.trackEvent(event: Event.deleteOrphansStart(count: orphanedQuizzes.count))

        var localDeletedCount = 0
        for quiz in orphanedQuizzes {
            do {
                try local.deleteQuiz(id: quiz.id)
                quizzes.removeAll { $0.id == quiz.id }
                localDeletedCount += 1
                deleteQuizFromRemote(quizId: quiz.id)
            } catch {
                logManager?.trackEvent(event: Event.deleteOrphansFail(error: error))
            }
        }

        logManager?.trackEvent(event: Event.deleteOrphansSuccess(
            localDeletedCount: localDeletedCount,
            remoteDispatchedCount: userId == nil ? 0 : localDeletedCount
        ))
    }

    // MARK: - Remote Sync Helpers

    /// Pushes a quiz to remote in the background. No-ops when signed out.
    private func pushQuizToRemote(_ quiz: QuizModel) {
        guard let userId else { return }
        Task {
            do {
                try await remote.saveQuiz(userId: userId, quiz: quiz)
                logManager?.trackEvent(event: Event.remotePushSuccess(quizId: quiz.id))
            } catch {
                logManager?.trackEvent(event: Event.remotePushFail(error: error))
            }
        }
    }

    /// Deletes a quiz remotely in the background. No-ops when signed out.
    private func deleteQuizFromRemote(quizId: String) {
        guard let userId else { return }
        Task {
            do {
                try await remote.deleteQuiz(userId: userId, quizId: quizId)
                logManager?.trackEvent(event: Event.remoteDeleteSuccess(quizId: quizId))
            } catch {
                logManager?.trackEvent(event: Event.remoteDeleteFail(error: error))
            }
        }
    }

    /// Deletes a deck's quizzes remotely in the background. No-ops when signed out.
    private func deleteDeckQuizzesFromRemote(deckId: String) {
        guard let userId else { return }
        Task {
            do {
                try await remote.deleteQuizzes(userId: userId, deckId: deckId)
                logManager?.trackEvent(event: Event.remoteDeleteDeckQuizzesSuccess(deckId: deckId))
            } catch {
                logManager?.trackEvent(event: Event.remoteDeleteDeckQuizzesFail(error: error))
            }
        }
    }

    // MARK: - Events

    enum Event: LoggableEvent {
        case logInStart(userId: String)
        case logInSuccess(userId: String, count: Int)
        case logInFail(error: Error)
        case signOut
        case loadQuizzesStart
        case loadQuizzesSuccess(count: Int)
        case loadQuizzesFail(error: Error)
        case loadQuizzesSkippedCorrupt(count: Int)
        case createQuizStart(deckId: String)
        case createQuizSuccess(quiz: QuizModel)
        case createQuizFail(error: Error)
        case recordAttemptStart(quizId: String)
        case recordAttemptSuccess(quiz: QuizModel)
        case recordAttemptFail(error: Error)
        case deleteQuizStart(quizId: String)
        case deleteQuizSuccess(quizId: String)
        case deleteQuizFail(error: Error)
        case deleteDeckQuizzesStart(deckId: String)
        case deleteDeckQuizzesSuccess(deckId: String)
        case deleteDeckQuizzesFail(error: Error)
        case deleteAllQuizzesStart
        case deleteAllQuizzesSuccess
        case deleteAllQuizzesFail(error: Error)
        case deleteOrphansStart(count: Int)
        case deleteOrphansSuccess(localDeletedCount: Int, remoteDispatchedCount: Int)
        case deleteOrphansFail(error: Error)
        case migrateQuizzesStart(count: Int)
        case migrateQuizzesSuccess(count: Int)
        case remotePushSuccess(quizId: String)
        case remotePushFail(error: Error)
        case remoteDeleteSuccess(quizId: String)
        case remoteDeleteFail(error: Error)
        case remoteDeleteDeckQuizzesSuccess(deckId: String)
        case remoteDeleteDeckQuizzesFail(error: Error)

        var eventName: String {
            switch self {
            case .logInStart:                       return "QuizMan_LogIn_Start"
            case .logInSuccess:                     return "QuizMan_LogIn_Success"
            case .logInFail:                        return "QuizMan_LogIn_Fail"
            case .signOut:                          return "QuizMan_SignOut"
            case .loadQuizzesStart:                 return "QuizMan_LoadQuizzes_Start"
            case .loadQuizzesSuccess:               return "QuizMan_LoadQuizzes_Success"
            case .loadQuizzesFail:                  return "QuizMan_LoadQuizzes_Fail"
            case .loadQuizzesSkippedCorrupt:        return "QuizMan_LoadQuizzes_SkippedCorrupt"
            case .createQuizStart:                  return "QuizMan_CreateQuiz_Start"
            case .createQuizSuccess:                return "QuizMan_CreateQuiz_Success"
            case .createQuizFail:                   return "QuizMan_CreateQuiz_Fail"
            case .recordAttemptStart:               return "QuizMan_RecordAttempt_Start"
            case .recordAttemptSuccess:             return "QuizMan_RecordAttempt_Success"
            case .recordAttemptFail:                return "QuizMan_RecordAttempt_Fail"
            case .deleteQuizStart:                  return "QuizMan_DeleteQuiz_Start"
            case .deleteQuizSuccess:                return "QuizMan_DeleteQuiz_Success"
            case .deleteQuizFail:                   return "QuizMan_DeleteQuiz_Fail"
            case .deleteDeckQuizzesStart:           return "QuizMan_DeleteDeckQuizzes_Start"
            case .deleteDeckQuizzesSuccess:         return "QuizMan_DeleteDeckQuizzes_Success"
            case .deleteDeckQuizzesFail:            return "QuizMan_DeleteDeckQuizzes_Fail"
            case .deleteAllQuizzesStart:            return "QuizMan_DeleteAllQuizzes_Start"
            case .deleteAllQuizzesSuccess:          return "QuizMan_DeleteAllQuizzes_Success"
            case .deleteAllQuizzesFail:             return "QuizMan_DeleteAllQuizzes_Fail"
            case .deleteOrphansStart:               return "QuizMan_DeleteOrphans_Start"
            case .deleteOrphansSuccess:             return "QuizMan_DeleteOrphans_Success"
            case .deleteOrphansFail:                return "QuizMan_DeleteOrphans_Fail"
            case .migrateQuizzesStart:              return "QuizMan_MigrateQuizzes_Start"
            case .migrateQuizzesSuccess:            return "QuizMan_MigrateQuizzes_Success"
            case .remotePushSuccess:                return "QuizMan_RemotePush_Success"
            case .remotePushFail:                   return "QuizMan_RemotePush_Fail"
            case .remoteDeleteSuccess:              return "QuizMan_RemoteDelete_Success"
            case .remoteDeleteFail:                 return "QuizMan_RemoteDelete_Fail"
            case .remoteDeleteDeckQuizzesSuccess:   return "QuizMan_RemoteDeleteDeckQuizzes_Success"
            case .remoteDeleteDeckQuizzesFail:      return "QuizMan_RemoteDeleteDeckQuizzes_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .logInStart(userId: let userId):
                return ["user_id": userId]
            case .logInSuccess(userId: let userId, count: let count):
                return ["user_id": userId, "quiz_count": count]
            case .loadQuizzesSuccess(count: let count),
                    .deleteOrphansStart(count: let count),
                    .migrateQuizzesStart(count: let count),
                    .migrateQuizzesSuccess(count: let count):
                return ["quiz_count": count]
            case .loadQuizzesSkippedCorrupt(count: let count):
                return ["skipped_count": count]
            case .deleteOrphansSuccess(localDeletedCount: let localDeletedCount, remoteDispatchedCount: let remoteDispatchedCount):
                return ["local_deleted_count": localDeletedCount, "remote_dispatched_count": remoteDispatchedCount]
            case .createQuizStart(deckId: let deckId),
                    .deleteDeckQuizzesStart(deckId: let deckId),
                    .deleteDeckQuizzesSuccess(deckId: let deckId),
                    .remoteDeleteDeckQuizzesSuccess(deckId: let deckId):
                return ["deck_id": deckId]
            case .createQuizSuccess(quiz: let quiz), .recordAttemptSuccess(quiz: let quiz):
                return quiz.eventParameters
            case .recordAttemptStart(quizId: let quizId),
                    .deleteQuizStart(quizId: let quizId),
                    .deleteQuizSuccess(quizId: let quizId),
                    .remotePushSuccess(quizId: let quizId),
                    .remoteDeleteSuccess(quizId: let quizId):
                return ["quiz_id": quizId]
            case .logInFail(error: let error),
                    .loadQuizzesFail(error: let error),
                    .createQuizFail(error: let error),
                    .recordAttemptFail(error: let error),
                    .deleteQuizFail(error: let error),
                    .deleteDeckQuizzesFail(error: let error),
                    .deleteAllQuizzesFail(error: let error),
                    .deleteOrphansFail(error: let error),
                    .remotePushFail(error: let error),
                    .remoteDeleteFail(error: let error),
                    .remoteDeleteDeckQuizzesFail(error: let error):
                return error.eventParameters
            case .signOut, .loadQuizzesStart, .deleteAllQuizzesStart, .deleteAllQuizzesSuccess:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .logInFail, .loadQuizzesFail, .createQuizFail, .recordAttemptFail, .deleteQuizFail,
                    .deleteDeckQuizzesFail, .deleteAllQuizzesFail, .deleteOrphansFail,
                    .remotePushFail, .remoteDeleteFail, .remoteDeleteDeckQuizzesFail:
                return .severe
            case .loadQuizzesSkippedCorrupt:
                return .warning
            default:
                return .analytic
            }
        }
    }
}
