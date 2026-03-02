//
//  PracticeInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/10/26.
//

import SwiftUI

@MainActor
protocol PracticeInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var currentStreakData: CurrentStreakData { get }
    var isPremium: Bool { get }
    var isReminderEnabled: Bool { get }
    func addStreakEvent(metadata: [String: GamificationDictionaryValue]) async throws -> StreakEvent
    func getDeck(id: String) -> DeckModel?
    func updateDeck(_ deck: DeckModel) throws
    func markFirstPracticeComplete() async throws
    func schedulePushNotificationsForTheNextWeek(dueCount: Int, stillLearningCount: Int)
}

extension CoreInteractor: PracticeInteractor { }
