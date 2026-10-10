//
//  QuizQuestionModel.swift
//  Keyoku
//

import Foundation
import IdentifiableByString

/// One multiple-choice question: exactly one correct answer, three wrong answers
/// and a one-sentence explanation. The stable `id` lets later features
/// (per-question records) reference a question without a migration.
struct QuizQuestionModel: StringIdentifiable, Codable, Sendable, Hashable {
    let id: String
    let question: String
    let correctAnswer: String
    let wrongAnswers: [String]
    let explanation: String

    init(
        id: String = UUID().uuidString,
        question: String,
        correctAnswer: String,
        wrongAnswers: [String],
        explanation: String
    ) {
        self.id = id
        self.question = question
        self.correctAnswer = correctAnswer
        self.wrongAnswers = wrongAnswers
        self.explanation = explanation
    }

    enum CodingKeys: String, CodingKey {
        case id
        case question
        case correctAnswer = "correct_answer"
        case wrongAnswers = "wrong_answers"
        case explanation
    }

    var eventParameters: [String: Any] {
        [
            "question_\(CodingKeys.id.rawValue)": id,
            "question_wrong_answer_count": wrongAnswers.count
        ]
    }

    static var mock: Self {
        mocks[0]
    }

    static var mocks: [Self] {
        [
            QuizQuestionModel(
                id: "question1",
                question: "How do you say \"hello\" in Spanish?",
                correctAnswer: "Hola",
                wrongAnswers: ["Adiós", "Gracias", "Por favor"],
                explanation: "\"Hola\" is the standard Spanish greeting."
            ),
            QuizQuestionModel(
                id: "question2",
                question: "What does \"gracias\" mean?",
                correctAnswer: "Thank you",
                wrongAnswers: ["Please", "Goodbye", "Excuse me"],
                explanation: "\"Gracias\" is how you thank someone in Spanish."
            ),
            QuizQuestionModel(
                id: "question3",
                question: "Which verb means \"to be\" for lasting traits?",
                correctAnswer: "Ser",
                wrongAnswers: ["Estar", "Tener", "Hacer"],
                explanation: "\"Ser\" describes lasting characteristics, while \"estar\" describes states."
            ),
            QuizQuestionModel(
                id: "question4",
                question: "How do you say \"goodbye\" in Spanish?",
                correctAnswer: "Adiós",
                wrongAnswers: ["Hola", "Buenas", "Perdón"],
                explanation: "\"Adiós\" is the common way to say goodbye."
            ),
            QuizQuestionModel(
                id: "question5",
                question: "What is the Spanish word for \"please\"?",
                correctAnswer: "Por favor",
                wrongAnswers: ["De nada", "Lo siento", "Con permiso"],
                explanation: "\"Por favor\" is used to make polite requests."
            )
        ]
    }
}
