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
    var deck: DeckEntity?

    init(id: String = UUID().uuidString, question: String, answer: String, isLearned: Bool = false) {
        self.id = id
        self.question = question
        self.answer = answer
        self.isLearned = isLearned
    }

    convenience init(from model: FlashcardModel) {
        self.init(id: model.flashcardId, question: model.question, answer: model.answer, isLearned: model.isLearned)
    }

    func toModel() -> FlashcardModel {
        FlashcardModel(
            flashcardId: id,
            question: question,
            answer: answer,
            deckId: deck?.id,
            isLearned: isLearned
        )
    }
}
