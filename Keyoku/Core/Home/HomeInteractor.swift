import SwiftUI

@MainActor
protocol HomeInteractor: GlobalInteractor {
    // Deck data
    var decks: [DeckModel] { get }
    func loadDecks()

    // Quiz data
    var quizzes: [QuizModel] { get }
    func loadQuizzes()
}

extension CoreInteractor: HomeInteractor { }
