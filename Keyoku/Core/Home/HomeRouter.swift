import SwiftUI

@MainActor
protocol HomeRouter: GlobalRouter {
    func showDevSettingsView()
    func showDeckDetailView(deck: DeckModel)
    func showCreateDeckView()
}

extension CoreRouter: HomeRouter { }
