import SwiftUI

@MainActor
protocol HomeInteractor: GlobalInteractor {
    // Deck data
    var decks: [DeckModel] { get }
    func loadDecks()
    func getDeck(id: String) -> DeckModel?

    // Quiz data
    var quizzes: [QuizModel] { get }
    func loadQuizzes()
    func getQuiz(id: String) -> QuizModel?
    
    func schedulePushNotificationsForTheNextWeek()
    func requestPushAuthorization() async throws -> Bool
    
    func canRequestPushAuthorization() async -> Bool

    // Spotlight
    func parseSpotlightIdentifier(_ identifier: String) -> (type: String, id: String)?
}

extension CoreInteractor: HomeInteractor { }
