import SwiftUI

@MainActor
protocol HomeInteractor: GlobalInteractor {
    // Deck data
    var decks: [DeckModel] { get }
    func loadDecks()
    func getDeck(id: String) -> DeckModel?

    func schedulePushNotificationsForTheNextWeek()
    func requestPushAuthorization() async throws -> Bool

    func canRequestPushAuthorization() async -> Bool

    // Spotlight
    func parseSpotlightIdentifier(_ identifier: String) -> (type: String, id: String)?
}

extension CoreInteractor: HomeInteractor { }
