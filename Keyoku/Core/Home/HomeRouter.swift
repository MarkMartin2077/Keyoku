import SwiftUI

@MainActor
protocol HomeRouter: GlobalRouter {
    func showDevSettingsView()
    func showDeckDetailView(deck: DeckModel)
    func showCreateContentView()
    func showDecksView(delegate: DecksDelegate)
}

extension CoreRouter: HomeRouter { }
