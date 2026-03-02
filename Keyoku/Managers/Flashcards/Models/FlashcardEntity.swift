//
//  FlashcardEntity.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import Foundation
import SwiftData

@Model
class FlashcardEntity {
    @Attribute(.unique) var id: String = UUID().uuidString
    var question: String = ""
    var answer: String = ""
    var isLearned: Bool = false
    var repetitions: Int = 0
    var interval: Int = 0
    var easeFactor: Double = 2.5
    var dueDate: Date?
    var stillLearningCount: Int = 0
    var deck: DeckEntity?

    init(
        id: String = UUID().uuidString,
        question: String,
        answer: String,
        isLearned: Bool = false,
        repetitions: Int = 0,
        interval: Int = 0,
        easeFactor: Double = 2.5,
        dueDate: Date? = nil,
        stillLearningCount: Int = 0
    ) {
        self.id = id
        self.question = question
        self.answer = answer
        self.isLearned = isLearned
        self.repetitions = repetitions
        self.interval = interval
        self.easeFactor = easeFactor
        self.dueDate = dueDate
        self.stillLearningCount = stillLearningCount
    }

    convenience init(from model: FlashcardModel) {
        self.init(
            id: model.flashcardId,
            question: model.question,
            answer: model.answer,
            isLearned: model.isLearned,
            repetitions: model.repetitions,
            interval: model.interval,
            easeFactor: model.easeFactor,
            dueDate: model.dueDate,
            stillLearningCount: model.stillLearningCount
        )
    }

    func toModel() -> FlashcardModel {
        FlashcardModel(
            flashcardId: id,
            question: question,
            answer: answer,
            deckId: deck?.id,
            isLearned: isLearned,
            repetitions: repetitions,
            interval: interval,
            easeFactor: easeFactor,
            dueDate: dueDate,
            stillLearningCount: stillLearningCount
        )
    }
}
