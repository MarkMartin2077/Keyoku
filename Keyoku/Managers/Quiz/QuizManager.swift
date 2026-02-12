//
//  QuizManager.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@MainActor
@Observable
class QuizManager {

    private let local: QuizService
    private let logManager: LogManager?

    private(set) var quizzes: [QuizModel] = []

    init(services: QuizServices, logManager: LogManager? = nil) {
        self.local = services.local
        self.logManager = logManager
    }

    // MARK: - Quiz Operations

    func loadQuizzes() {
        logManager?.trackEvent(event: Event.loadQuizzesStart)

        do {
            quizzes = try local.getAllQuizzes()
            logManager?.trackEvent(event: Event.loadQuizzesSuccess(count: quizzes.count))
        } catch {
            logManager?.trackEvent(event: Event.loadQuizzesFail(error: error))
        }
    }

    func getQuiz(id: String) -> QuizModel? {
        quizzes.first { $0.quizId == id }
    }

    func createQuiz(name: String, color: DeckColor = .blue, sourceText: String) throws {
        logManager?.trackEvent(event: Event.createQuizStart(name: name))

        let quiz = QuizModel(name: name, color: color, sourceText: sourceText)

        do {
            try local.saveQuiz(quiz: quiz)
            quizzes.insert(quiz, at: 0)
            logManager?.trackEvent(event: Event.createQuizSuccess(quiz: quiz))
        } catch {
            logManager?.trackEvent(event: Event.createQuizFail(error: error))
            throw error
        }
    }

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
        } catch {
            logManager?.trackEvent(event: Event.createQuizFail(error: error))
            throw error
        }
    }

    func deleteQuiz(id: String) throws {
        logManager?.trackEvent(event: Event.deleteQuizStart(quizId: id))

        do {
            try local.deleteQuiz(id: id)
            quizzes.removeAll { $0.quizId == id }
            logManager?.trackEvent(event: Event.deleteQuizSuccess(quizId: id))
        } catch {
            logManager?.trackEvent(event: Event.deleteQuizFail(error: error))
            throw error
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

        var eventName: String {
            switch self {
            case .loadQuizzesStart:     return "QuizMan_LoadQuizzes_Start"
            case .loadQuizzesSuccess:   return "QuizMan_LoadQuizzes_Success"
            case .loadQuizzesFail:      return "QuizMan_LoadQuizzes_Fail"
            case .createQuizStart:      return "QuizMan_CreateQuiz_Start"
            case .createQuizSuccess:    return "QuizMan_CreateQuiz_Success"
            case .createQuizFail:       return "QuizMan_CreateQuiz_Fail"
            case .deleteQuizStart:      return "QuizMan_DeleteQuiz_Start"
            case .deleteQuizSuccess:    return "QuizMan_DeleteQuiz_Success"
            case .deleteQuizFail:       return "QuizMan_DeleteQuiz_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .loadQuizzesSuccess(count: let count):
                return ["quiz_count": count]
            case .createQuizStart(name: let name):
                return ["quiz_name": name]
            case .createQuizSuccess(quiz: let quiz):
                return quiz.eventParameters
            case .deleteQuizStart(quizId: let id), .deleteQuizSuccess(quizId: let id):
                return ["quiz_id": id]
            case .loadQuizzesFail(error: let error), .createQuizFail(error: let error), .deleteQuizFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .loadQuizzesFail, .createQuizFail, .deleteQuizFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
