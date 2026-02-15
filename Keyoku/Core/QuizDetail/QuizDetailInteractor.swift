//
//  QuizDetailInteractor.swift
//  Keyoku
//

import SwiftUI

@MainActor
protocol QuizDetailInteractor: GlobalInteractor {
    func getQuiz(id: String) -> QuizModel?
    func deleteQuizQuestion(questionId: String, fromQuizId: String) throws
}

extension CoreInteractor: QuizDetailInteractor { }
