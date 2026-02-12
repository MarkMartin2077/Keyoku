//
//  QuizQuestionModel.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation
import IdentifiableByString

struct QuizQuestionModel: StringIdentifiable, Codable, Sendable {
    var id: String {
        questionId
    }

    let questionId: String
    let quizId: String?
    let questionType: QuestionType
    let questionText: String
    let options: [String]
    let correctAnswerIndex: Int

    init(
        questionId: String = UUID().uuidString,
        quizId: String? = nil,
        questionType: QuestionType,
        questionText: String,
        options: [String],
        correctAnswerIndex: Int
    ) {
        self.questionId = questionId
        self.quizId = quizId
        self.questionType = questionType
        self.questionText = questionText
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
    }

    init(entity: QuizQuestionEntity) {
        self.questionId = entity.id
        self.quizId = entity.quiz?.id
        self.questionType = entity.questionType
        self.questionText = entity.questionText
        self.options = entity.options
        self.correctAnswerIndex = entity.correctAnswerIndex
    }

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case quizId = "quiz_id"
        case questionType = "question_type"
        case questionText = "question_text"
        case options
        case correctAnswerIndex = "correct_answer_index"
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "question_\(CodingKeys.questionId.rawValue)": questionId,
            "question_\(CodingKeys.quizId.rawValue)": quizId,
            "question_\(CodingKeys.questionType.rawValue)": questionType.rawValue,
            "question_\(CodingKeys.questionText.rawValue)": questionText,
            "question_\(CodingKeys.correctAnswerIndex.rawValue)": correctAnswerIndex
        ]
        return dict.compactMapValues({ $0 })
    }

    func toEntity() -> QuizQuestionEntity {
        QuizQuestionEntity(
            id: questionId,
            questionType: questionType,
            questionText: questionText,
            options: options,
            correctAnswerIndex: correctAnswerIndex
        )
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        [
            QuizQuestionModel(
                questionId: "question1",
                questionType: .multipleChoice,
                questionText: "What is the capital of Japan?",
                options: ["Beijing", "Seoul", "Tokyo", "Bangkok"],
                correctAnswerIndex: 2,
                quizId: "quiz1"
            ),
            QuizQuestionModel(
                questionId: "question2",
                questionType: .multipleChoice,
                questionText: "Which planet is known as the Red Planet?",
                options: ["Venus", "Mars", "Jupiter", "Saturn"],
                correctAnswerIndex: 1,
                quizId: "quiz1"
            ),
            QuizQuestionModel(
                questionId: "question3",
                questionType: .trueFalse,
                questionText: "The Great Wall of China is visible from space.",
                options: ["True", "False"],
                correctAnswerIndex: 1,
                quizId: "quiz1"
            ),
            QuizQuestionModel(
                questionId: "question4",
                questionType: .trueFalse,
                questionText: "Water boils at 100 degrees Celsius at sea level.",
                options: ["True", "False"],
                correctAnswerIndex: 0,
                quizId: "quiz1"
            )
        ]
    }
}

extension QuizQuestionModel {
    init(
        questionId: String = UUID().uuidString,
        questionType: QuestionType,
        questionText: String,
        options: [String],
        correctAnswerIndex: Int,
        quizId: String?
    ) {
        self.questionId = questionId
        self.quizId = quizId
        self.questionType = questionType
        self.questionText = questionText
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
    }
}
