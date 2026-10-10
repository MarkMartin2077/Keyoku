//
//  QuizQuestionCount.swift
//  Keyoku
//

import Foundation

/// How many questions a quiz may have, given the length of the deck's source text.
/// One question per 300 characters, between 5 and 20, so short decks aren't asked for more than they hold.
enum QuizQuestionCount {
    static let minimum = 5
    static let ceiling = 20
    static let preferred = 10
    static let charactersPerQuestion = 300

    /// 1,500 characters: enough for the minimum number of questions.
    static let minimumSourceLength = minimum * charactersPerQuestion

    static func canMakeQuiz(sourceLength: Int) -> Bool {
        sourceLength >= minimumSourceLength
    }

    /// `clamp(sourceLength / 300, 5, 20)`.
    static func maximum(sourceLength: Int) -> Int {
        min(max(sourceLength / charactersPerQuestion, minimum), ceiling)
    }

    /// The stepper's starting value: `min(10, maximum)`.
    static func defaultCount(sourceLength: Int) -> Int {
        min(preferred, maximum(sourceLength: sourceLength))
    }

    /// `count` moved into the range this source allows.
    static func clamped(_ count: Int, sourceLength: Int) -> Int {
        min(max(count, minimum), maximum(sourceLength: sourceLength))
    }
}
