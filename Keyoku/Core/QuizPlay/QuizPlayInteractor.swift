//
//  QuizPlayInteractor.swift
//  Keyoku
//

import SwiftUI

@MainActor
protocol QuizPlayInteractor: GlobalInteractor {
    var currentStreakData: CurrentStreakData { get }
    func addStreakEvent(metadata: [String: GamificationDictionaryValue]) async throws -> StreakEvent
    func recordQuizAttempt(quizId: String, score: Int, total: Int) throws -> QuizModel
    func schedulePushNotificationsForTheNextWeek(dueCount: Int, stillLearningCount: Int)
}

extension CoreInteractor: QuizPlayInteractor { }
