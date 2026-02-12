//
//  QuizService.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@MainActor
protocol QuizService {
    func getAllQuizzes() throws -> [QuizModel]
    func getQuiz(id: String) throws -> QuizModel?
    func saveQuiz(quiz: QuizModel) throws
    func deleteQuiz(id: String) throws
}
