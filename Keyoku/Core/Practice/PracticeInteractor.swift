//
//  PracticeInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/10/26.
//

import SwiftUI

@MainActor
protocol PracticeInteractor: GlobalInteractor {
    @discardableResult func addStreakEvent(metadata: [String: GamificationDictionaryValue]) async throws -> StreakEvent
    @discardableResult func addExperiencePoints(points: Int, metadata: [String: GamificationDictionaryValue]) async throws -> ExperiencePointsEvent
}

extension CoreInteractor: PracticeInteractor { }
