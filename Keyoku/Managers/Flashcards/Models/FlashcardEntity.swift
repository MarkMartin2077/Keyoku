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
    var deck: DeckEntity?

    init(id: String = UUID().uuidString, question: String, answer: String) {
        self.id = id
        self.question = question
        self.answer = answer
    }
}
