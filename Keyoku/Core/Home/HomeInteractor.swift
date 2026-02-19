import SwiftUI

@MainActor
protocol HomeInteractor: GlobalInteractor {
    // Deck data
    var decks: [DeckModel] { get }
    func loadDecks()
    func getDeck(id: String) -> DeckModel?
    func updateDeck(_ deck: DeckModel) throws

    func schedulePushNotificationsForTheNextWeek()
    func requestPushAuthorization() async throws -> Bool

    func canRequestPushAuthorization() async -> Bool

    // Spotlight
    func parseSpotlightIdentifier(_ identifier: String) -> (type: String, id: String)?

    // User
    var currentUser: UserModel? { get }

    // Streaks
    var currentStreakData: CurrentStreakData { get }
}

extension CoreInteractor: HomeInteractor { }
