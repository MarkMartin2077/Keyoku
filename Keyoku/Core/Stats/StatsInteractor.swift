import SwiftUI

@MainActor
protocol StatsInteractor: GlobalInteractor {
    var decks: [DeckModel] { get }
    var currentStreakData: CurrentStreakData { get }
}

extension CoreInteractor: StatsInteractor { }
