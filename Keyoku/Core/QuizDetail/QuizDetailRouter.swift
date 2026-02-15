//
//  QuizDetailRouter.swift
//  Keyoku
//

import SwiftUI

@MainActor
protocol QuizDetailRouter: GlobalRouter {
    func showQuizView(quiz: QuizModel, startingAt: Int)
}

extension CoreRouter: QuizDetailRouter { }
