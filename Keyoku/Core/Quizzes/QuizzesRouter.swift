//
//  QuizzesRouter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@MainActor
protocol QuizzesRouter: GlobalRouter {
    func showQuizView(quiz: QuizModel)
    func showCreateDeckView()
}

extension CoreRouter: QuizzesRouter { }
