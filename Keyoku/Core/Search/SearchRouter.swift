//
//  SearchRouter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@MainActor
protocol SearchRouter: GlobalRouter {
    func showDeckDetailView(deck: DeckModel)
    func showQuizView(quiz: QuizModel)
}

extension CoreRouter: SearchRouter { }
