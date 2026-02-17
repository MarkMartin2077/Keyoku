//
//  PracticeInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/10/26.
//

import SwiftUI

@MainActor
protocol PracticeInteractor: GlobalInteractor {
    var currentStreakData: CurrentStreakData { get }
    func addStreakEvent(metadata: [String: GamificationDictionaryValue]) async throws -> StreakEvent
}

extension CoreInteractor: PracticeInteractor { }
