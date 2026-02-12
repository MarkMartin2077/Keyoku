import SwiftUI

@MainActor
protocol HomeRouter: GlobalRouter {
    func showDevSettingsView()
    func showDeckDetailView(deck: DeckModel)
    func showCreateContentView(defaultContentType: CreateDeckPresenter.ContentType?)
    func showDecksView(delegate: DecksDelegate)
    func showSettingsView()
    func showQuizView(quiz: QuizModel)
}

extension CoreRouter: HomeRouter { }
