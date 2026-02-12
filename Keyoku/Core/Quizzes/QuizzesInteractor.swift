//
//  QuizzesInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@MainActor
protocol QuizzesInteractor: GlobalInteractor {
    var quizzes: [QuizModel] { get }
    func loadQuizzes()
    func deleteQuiz(id: String) throws
}

extension CoreInteractor: QuizzesInteractor { }
