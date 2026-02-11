import SwiftUI

@MainActor
protocol HomeInteractor: GlobalInteractor {
    // Deck data
    var decks: [DeckModel] { get }
    func loadDecks()

    // Streak data
    var currentStreakData: CurrentStreakData { get }
    @discardableResult func addStreakEvent(metadata: [String: GamificationDictionaryValue]) async throws -> StreakEvent

    // XP data
    var currentExperiencePointsData: CurrentExperiencePointsData { get }
}

extension CoreInteractor: HomeInteractor { }
