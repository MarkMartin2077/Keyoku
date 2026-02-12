//
//  QuizQuestionEntity.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation
import SwiftData

@Model
class QuizQuestionEntity {
    @Attribute(.unique) var id: String = UUID().uuidString
    var questionTypeRaw: String = QuestionType.multipleChoice.rawValue
    var questionText: String = ""
    var optionsData: Data = Data()
    var correctAnswerIndex: Int = 0
    var quiz: QuizEntity?

    var questionType: QuestionType {
        get { QuestionType(rawValue: questionTypeRaw) ?? .multipleChoice }
        set { questionTypeRaw = newValue.rawValue }
    }

    var options: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: optionsData)) ?? []
        }
        set {
            optionsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(
        id: String = UUID().uuidString,
        questionType: QuestionType,
        questionText: String,
        options: [String],
        correctAnswerIndex: Int
    ) {
        self.id = id
        self.questionTypeRaw = questionType.rawValue
        self.questionText = questionText
        self.optionsData = (try? JSONEncoder().encode(options)) ?? Data()
        self.correctAnswerIndex = correctAnswerIndex
    }

    convenience init(from model: QuizQuestionModel) {
        self.init(
            id: model.questionId,
            questionType: model.questionType,
            questionText: model.questionText,
            options: model.options,
            correctAnswerIndex: model.correctAnswerIndex
        )
    }

    func toModel() -> QuizQuestionModel {
        QuizQuestionModel(
            questionId: id,
            quizId: quiz?.id,
            questionType: questionType,
            questionText: questionText,
            options: options,
            correctAnswerIndex: correctAnswerIndex
        )
    }
}
