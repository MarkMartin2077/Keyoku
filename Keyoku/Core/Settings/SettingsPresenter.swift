//
//  SettingsPresenter.swift
//
//
//
//
import SwiftUI

/// Settings presenter for legal and app info links.
@Observable
@MainActor
class SettingsPresenter {

    private let interactor: SettingsInteractor
    private let router: SettingsRouter

    init(interactor: SettingsInteractor, router: SettingsRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onPrivacyPolicyPressed() {
        interactor.trackEvent(event: Event.privacyPolicyPressed)

        if let url = URL(string: Constants.privacyPolicyUrlString) {
            UIApplication.shared.open(url)
        }
    }

    func onTermsOfServicePressed() {
        interactor.trackEvent(event: Event.termsOfServicePressed)

        if let url = URL(string: Constants.termsOfServiceUrlString) {
            UIApplication.shared.open(url)
        }
    }

}

extension SettingsPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case privacyPolicyPressed
        case termsOfServicePressed

        var eventName: String {
            switch self {
            case .onAppear:             return "SettingsView_Appear"
            case .onDisappear:          return "SettingsView_Disappear"
            case .privacyPolicyPressed: return "SettingsView_PrivacyPolicy_Pressed"
            case .termsOfServicePressed: return "SettingsView_TermsOfService_Pressed"
            }
        }

        var parameters: [String: Any]? { nil }

        var type: LogType { .analytic }
    }

}
