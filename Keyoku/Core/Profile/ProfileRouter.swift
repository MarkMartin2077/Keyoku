import SwiftUI

@MainActor
protocol ProfileRouter: GlobalRouter {
    func showSettingsView()
    func showCreateAccountView(delegate: CreateAccountDelegate, onDismiss: (() -> Void)?)
    func switchToOnboardingModule()
    func showPaywallView(delegate: PaywallDelegate)
}

extension CoreRouter: ProfileRouter { }
