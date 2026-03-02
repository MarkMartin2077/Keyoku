import SwiftUI

@MainActor
protocol HomeInteractor: GlobalInteractor {
    // Deck data
    var decks: [DeckModel] { get }
    func loadDecks()
    func getDeck(id: String) -> DeckModel?
    func updateDeck(_ deck: DeckModel) throws

    func schedulePushNotificationsForTheNextWeek(dueCount: Int, stillLearningCount: Int)

    // Spotlight
    func parseSpotlightIdentifier(_ identifier: String) -> (type: String, id: String)?

    // User
    var currentUser: UserModel? { get }

    // Purchases
    var isPremium: Bool { get }
    var freeTierDeckLimit: Int { get }

    // Streaks
    var currentStreakData: CurrentStreakData { get }

    // A/B Tests
    var homePracticeLayout: HomePracticeLayoutOption { get }

    // Rating prompt
    var pendingRatingPrompt: Bool { get }
    func clearPendingRatingPrompt()
    func recordRatingPromptShown()
}

extension CoreInteractor: HomeInteractor { }
