import SwiftUI

@MainActor
protocol HomeRouter: GlobalRouter {
    func showDevSettingsView()
    func showDeckDetailView(deck: DeckModel)
    func showCreateContentView()
    func showDecksView(delegate: DecksDelegate)
    func showPaywallView(delegate: PaywallDelegate)
}

extension CoreRouter: HomeRouter { }
