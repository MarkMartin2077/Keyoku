//
//  SearchInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@MainActor
protocol SearchInteractor: GlobalInteractor {
    var decks: [DeckModel] { get }
    var quizzes: [QuizModel] { get }
    func loadDecks()
    func loadQuizzes()
}

extension CoreInteractor: SearchInteractor { }
