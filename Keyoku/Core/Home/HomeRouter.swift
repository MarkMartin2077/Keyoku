import SwiftUI

@MainActor
protocol HomeRouter: GlobalRouter {
    func showDevSettingsView()
    func showDeckDetailView(deck: DeckModel)
    func showCreateDeckView()
    func showDecksView(delegate: DecksDelegate)
    func showSettingsView()
}

extension CoreRouter: HomeRouter { }
