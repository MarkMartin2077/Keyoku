//
//  SwiftDataQuizPersistence.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation
import SwiftData

@MainActor
struct SwiftDataQuizPersistence: QuizService {
    private let container: ModelContainer

    private var mainContext: ModelContext {
        container.mainContext
    }

    init() {
        let config = ModelConfiguration("QuizStore")
        // swiftlint:disable:next force_try
        self.container = try! ModelContainer(for: QuizEntity.self, QuizQuestionEntity.self, configurations: config)
    }

    func getAllQuizzes() throws -> [QuizModel] {
        let descriptor = FetchDescriptor<QuizEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let entities = try mainContext.fetch(descriptor)
        return entities.map { $0.toModel() }
    }

    func getQuiz(id: String) throws -> QuizModel? {
        let predicate = #Predicate<QuizEntity> { $0.id == id }
        var descriptor = FetchDescriptor<QuizEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        let entities = try mainContext.fetch(descriptor)
        return entities.first?.toModel()
    }

    func saveQuiz(quiz: QuizModel) throws {
        let predicate = #Predicate<QuizEntity> { $0.id == quiz.quizId }
        var descriptor = FetchDescriptor<QuizEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        let existingEntities = try mainContext.fetch(descriptor)

        if let existingEntity = existingEntities.first {
            existingEntity.name = quiz.name
            existingEntity.color = quiz.color
            existingEntity.sourceText = quiz.sourceText
            existingEntity.createdAt = quiz.createdAt

            for question in existingEntity.questions {
                mainContext.delete(question)
            }
            existingEntity.questions.removeAll()

            for question in quiz.questions {
                let questionEntity = QuizQuestionEntity(
                    id: question.questionId,
                    questionType: question.questionType,
                    questionText: question.questionText,
                    options: question.options,
                    correctAnswerIndex: question.correctAnswerIndex
                )
                questionEntity.quiz = existingEntity
                mainContext.insert(questionEntity)
            }
        } else {
            let quizEntity = QuizEntity(
                id: quiz.quizId,
                name: quiz.name,
                color: quiz.color,
                sourceText: quiz.sourceText,
                createdAt: quiz.createdAt
            )
            mainContext.insert(quizEntity)

            for question in quiz.questions {
                let questionEntity = QuizQuestionEntity(
                    id: question.questionId,
                    questionType: question.questionType,
                    questionText: question.questionText,
                    options: question.options,
                    correctAnswerIndex: question.correctAnswerIndex
                )
                questionEntity.quiz = quizEntity
                mainContext.insert(questionEntity)
            }
        }

        try mainContext.save()
    }

    func deleteQuiz(id: String) throws {
        let predicate = #Predicate<QuizEntity> { $0.id == id }
        var descriptor = FetchDescriptor<QuizEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        let entities = try mainContext.fetch(descriptor)

        if let entity = entities.first {
            mainContext.delete(entity)
            try mainContext.save()
        }
    }
}

enum QuizPersistenceError: LocalizedError {
    case quizNotFound

    var errorDescription: String? {
        switch self {
        case .quizNotFound:
            return "Quiz not found"
        }
    }
}
