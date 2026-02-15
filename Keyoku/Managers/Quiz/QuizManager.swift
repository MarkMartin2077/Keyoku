//
//  QuizManager.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

/// Manages quiz CRUD operations using a local-first architecture with remote backup.
///
/// **Data Flow:**
/// 1. All writes go to local storage first (synchronous, immediate)
/// 2. The in-memory `quizzes` array is updated to reflect the change
/// 3. A fire-and-forget `Task` pushes the change to the remote service
///
/// **Login Sync:**
/// On `logIn`, remote quizzes are fetched and merged into local storage.
/// If the remote fetch fails, the manager falls back to whatever is cached locally.
///
/// **Dependencies:**
/// - `QuizService` (local) — synchronous, file-based persistence
/// - `RemoteQuizService` (remote) — async, typically Firestore-backed
/// - `LogManager` — optional analytics tracking for every operation
@MainActor
@Observable
class QuizManager {

    private let local: QuizService
    private let remote: RemoteQuizService
    private let logManager: LogManager?
    private var userId: String?

    /// The current user's quizzes, loaded from local storage.
    /// Updated in-place on create/delete to avoid full reloads.
    private(set) var quizzes: [QuizModel] = []

    init(services: QuizServices, logManager: LogManager? = nil) {
        self.local = services.local
        self.remote = services.remote
        self.logManager = logManager
    }

    // MARK: - Auth Lifecycle

    /// Syncs remote quizzes to local storage and loads them into memory.
    ///
    /// Remote quizzes are saved locally one at a time using `try?` so that a
    /// single corrupt quiz doesn't prevent the rest from syncing. If the entire
    /// remote fetch fails, the manager falls back to whatever is already cached locally.
    ///
    /// - Parameter userId: The authenticated user's ID, stored for remote operations.
    func logIn(userId: String) async throws {
        self.userId = userId
        logManager?.trackEvent(event: Event.logInStart(userId: userId))

        do {
            let remoteQuizzes = try await remote.getAllQuizzes(userId: userId)
            for quiz in remoteQuizzes {
                try? local.saveQuiz(quiz: quiz)
            }
            loadQuizzes()
            logManager?.trackEvent(event: Event.logInSuccess(userId: userId, count: quizzes.count))
        } catch {
            logManager?.trackEvent(event: Event.logInFail(error: error))
            loadQuizzes()
        }
    }

    /// Clears the userId and in-memory quizzes. Local storage is not deleted.
    func signOut() {
        logManager?.trackEvent(event: Event.signOut)
        userId = nil
        quizzes = []
    }

    // MARK: - Quiz Operations

    /// Reloads all quizzes from local storage into the in-memory `quizzes` array.
    /// Errors are logged but do not throw — the array simply remains unchanged.
    func loadQuizzes() {
        logManager?.trackEvent(event: Event.loadQuizzesStart)

        do {
            quizzes = try local.getAllQuizzes()
            logManager?.trackEvent(event: Event.loadQuizzesSuccess(count: quizzes.count))
        } catch {
            logManager?.trackEvent(event: Event.loadQuizzesFail(error: error))
        }
    }

    /// Returns a quiz from the in-memory array by its ID, or `nil` if not found.
    func getQuiz(id: String) -> QuizModel? {
        quizzes.first { $0.quizId == id }
    }

    /// Creates an empty quiz (no questions) and persists it locally.
    ///
    /// The quiz is inserted at index 0 so it appears first in the list,
    /// then pushed to remote in the background.
    ///
    /// - Parameters:
    ///   - name: Display name for the quiz.
    ///   - color: Theme color (defaults to `.blue`).
    ///   - sourceText: The original text used to generate the quiz.
    func createQuiz(name: String, color: DeckColor = .blue, sourceText: String) throws {
        logManager?.trackEvent(event: Event.createQuizStart(name: name))

        let quiz = QuizModel(name: name, color: color, sourceText: sourceText)

        do {
            try local.saveQuiz(quiz: quiz)
            quizzes.insert(quiz, at: 0)
            logManager?.trackEvent(event: Event.createQuizSuccess(quiz: quiz))
            pushQuizToRemote(quiz)
        } catch {
            logManager?.trackEvent(event: Event.createQuizFail(error: error))
            throw error
        }
    }

    /// Creates a quiz with pre-generated questions.
    ///
    /// A new `quizId` is generated, and each question's `quizId` field is
    /// remapped to match it. This ensures consistent parent-child relationships
    /// even when questions were generated before the quiz existed (e.g., from AI generation).
    ///
    /// - Parameters:
    ///   - name: Display name for the quiz.
    ///   - color: Theme color (defaults to `.blue`).
    ///   - sourceText: The original text used to generate the quiz.
    ///   - questions: Pre-generated questions whose `quizId` will be overwritten.
    func createQuiz(name: String, color: DeckColor = .blue, sourceText: String, questions: [QuizQuestionModel]) throws {
        logManager?.trackEvent(event: Event.createQuizStart(name: name))

        let quizId = UUID().uuidString
        let questionsWithQuizId = questions.map { question in
            QuizQuestionModel(
                questionId: question.questionId,
                questionType: question.questionType,
                questionText: question.questionText,
                options: question.options,
                correctAnswerIndex: question.correctAnswerIndex,
                quizId: quizId
            )
        }

        let quiz = QuizModel(
            quizId: quizId,
            name: name,
            color: color,
            sourceText: sourceText,
            questions: questionsWithQuizId
        )

        do {
            try local.saveQuiz(quiz: quiz)
            quizzes.insert(quiz, at: 0)
            logManager?.trackEvent(event: Event.createQuizSuccess(quiz: quiz))
            pushQuizToRemote(quiz)
        } catch {
            logManager?.trackEvent(event: Event.createQuizFail(error: error))
            throw error
        }
    }

    /// Deletes a quiz from local storage and removes it from the in-memory array.
    /// The remote deletion happens in the background via fire-and-forget.
    func deleteQuiz(id: String) throws {
        logManager?.trackEvent(event: Event.deleteQuizStart(quizId: id))

        do {
            try local.deleteQuiz(id: id)
            quizzes.removeAll { $0.quizId == id }
            logManager?.trackEvent(event: Event.deleteQuizSuccess(quizId: id))
            deleteQuizFromRemote(quizId: id)
        } catch {
            logManager?.trackEvent(event: Event.deleteQuizFail(error: error))
            throw error
        }
    }

    /// Deletes a single question from a quiz by filtering it out and saving the updated quiz.
    ///
    /// - Parameters:
    ///   - questionId: The ID of the question to remove.
    ///   - quizId: The ID of the quiz containing the question.
    func deleteQuizQuestion(questionId: String, fromQuizId quizId: String) throws {
        logManager?.trackEvent(event: Event.deleteQuestionStart(questionId: questionId, quizId: quizId))

        guard let quiz = getQuiz(id: quizId) else {
            let error = AppError("Quiz not found")
            logManager?.trackEvent(event: Event.deleteQuestionFail(error: error))
            throw error
        }

        let updatedQuestions = quiz.questions.filter { $0.questionId != questionId }
        let updatedQuiz = QuizModel(
            quizId: quiz.quizId,
            name: quiz.name,
            color: quiz.color,
            sourceText: quiz.sourceText,
            createdAt: quiz.createdAt,
            questions: updatedQuestions
        )

        do {
            try local.saveQuiz(quiz: updatedQuiz)
            if let index = quizzes.firstIndex(where: { $0.quizId == quizId }) {
                quizzes[index] = updatedQuiz
            }
            logManager?.trackEvent(event: Event.deleteQuestionSuccess(questionId: questionId, quizId: quizId))
            pushQuizToRemote(updatedQuiz)
        } catch {
            logManager?.trackEvent(event: Event.deleteQuestionFail(error: error))
            throw error
        }
    }

    // MARK: - Remote Sync Helpers

    /// Pushes a quiz to the remote service in the background.
    /// Failures are logged but do not surface to the caller (fire-and-forget).
    /// No-ops if the user is not signed in.
    private func pushQuizToRemote(_ quiz: QuizModel) {
        guard let userId else { return }
        Task {
            do {
                try await remote.saveQuiz(userId: userId, quiz: quiz)
                logManager?.trackEvent(event: Event.remotePushSuccess(quizId: quiz.quizId))
            } catch {
                logManager?.trackEvent(event: Event.remotePushFail(error: error))
            }
        }
    }

    /// Deletes a quiz from the remote service in the background.
    /// Failures are logged but do not surface to the caller (fire-and-forget).
    /// No-ops if the user is not signed in.
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

    // MARK: - Events

    enum Event: LoggableEvent {
        case loadQuizzesStart
        case loadQuizzesSuccess(count: Int)
        case loadQuizzesFail(error: Error)
        case createQuizStart(name: String)
        case createQuizSuccess(quiz: QuizModel)
        case createQuizFail(error: Error)
        case deleteQuizStart(quizId: String)
        case deleteQuizSuccess(quizId: String)
        case deleteQuizFail(error: Error)
        case logInStart(userId: String)
        case logInSuccess(userId: String, count: Int)
        case logInFail(error: Error)
        case signOut
        case remotePushSuccess(quizId: String)
        case remotePushFail(error: Error)
        case remoteDeleteSuccess(quizId: String)
        case remoteDeleteFail(error: Error)
        case deleteQuestionStart(questionId: String, quizId: String)
        case deleteQuestionSuccess(questionId: String, quizId: String)
        case deleteQuestionFail(error: Error)

        var eventName: String {
            switch self {
            case .loadQuizzesStart:         return "QuizMan_LoadQuizzes_Start"
            case .loadQuizzesSuccess:       return "QuizMan_LoadQuizzes_Success"
            case .loadQuizzesFail:          return "QuizMan_LoadQuizzes_Fail"
            case .createQuizStart:          return "QuizMan_CreateQuiz_Start"
            case .createQuizSuccess:        return "QuizMan_CreateQuiz_Success"
            case .createQuizFail:           return "QuizMan_CreateQuiz_Fail"
            case .deleteQuizStart:          return "QuizMan_DeleteQuiz_Start"
            case .deleteQuizSuccess:        return "QuizMan_DeleteQuiz_Success"
            case .deleteQuizFail:           return "QuizMan_DeleteQuiz_Fail"
            case .logInStart:               return "QuizMan_LogIn_Start"
            case .logInSuccess:             return "QuizMan_LogIn_Success"
            case .logInFail:                return "QuizMan_LogIn_Fail"
            case .signOut:                  return "QuizMan_SignOut"
            case .remotePushSuccess:        return "QuizMan_RemotePush_Success"
            case .remotePushFail:           return "QuizMan_RemotePush_Fail"
            case .remoteDeleteSuccess:      return "QuizMan_RemoteDelete_Success"
            case .remoteDeleteFail:         return "QuizMan_RemoteDelete_Fail"
            case .deleteQuestionStart:      return "QuizMan_DeleteQuestion_Start"
            case .deleteQuestionSuccess:    return "QuizMan_DeleteQuestion_Success"
            case .deleteQuestionFail:       return "QuizMan_DeleteQuestion_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .loadQuizzesSuccess(count: let count):
                return ["quiz_count": count]
            case .logInSuccess(userId: let userId, count: let count):
                return ["user_id": userId, "quiz_count": count]
            case .logInStart(userId: let userId):
                return ["user_id": userId]
            case .createQuizStart(name: let name):
                return ["quiz_name": name]
            case .createQuizSuccess(quiz: let quiz):
                return quiz.eventParameters
            case .deleteQuizStart(quizId: let id), .deleteQuizSuccess(quizId: let id), .remotePushSuccess(quizId: let id), .remoteDeleteSuccess(quizId: let id):
                return ["quiz_id": id]
            case .deleteQuestionStart(questionId: let qId, quizId: let quizId), .deleteQuestionSuccess(questionId: let qId, quizId: let quizId):
                return ["question_id": qId, "quiz_id": quizId]
            case .loadQuizzesFail(error: let error), .createQuizFail(error: let error), .deleteQuizFail(error: let error), .logInFail(error: let error), .remotePushFail(error: let error), .remoteDeleteFail(error: let error), .deleteQuestionFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .loadQuizzesFail, .createQuizFail, .deleteQuizFail, .logInFail, .remotePushFail, .remoteDeleteFail, .deleteQuestionFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
