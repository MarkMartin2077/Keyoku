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

    private(set) var showNotificationsRow: Bool = false

    init(interactor: SettingsInteractor, router: SettingsRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
        Task {
            showNotificationsRow = await interactor.canRequestPushAuthorization()
        }
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

    func onNotificationsPressed() {
        func onEnablePressed() {
            router.dismissModal()
            Task {
                let isAuthorized = (try? await interactor.requestPushAuthorization()) ?? false
                interactor.trackEvent(event: Event.notificationsEnable(isAuthorized: isAuthorized))
                showNotificationsRow = await interactor.canRequestPushAuthorization()
            }
        }

        func onCancelPressed() {
            router.dismissModal()
            interactor.trackEvent(event: Event.notificationsCancel)
        }

        interactor.trackEvent(event: Event.notificationsStart)
        router.showPushNotificationModal(
            onEnablePressed: { onEnablePressed() },
            onCancelPressed: { onCancelPressed() }
        )
    }

}

extension SettingsPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case privacyPolicyPressed
        case termsOfServicePressed
        case notificationsStart
        case notificationsEnable(isAuthorized: Bool)
        case notificationsCancel

        var eventName: String {
            switch self {
            case .onAppear:              return "SettingsView_Appear"
            case .onDisappear:           return "SettingsView_Disappear"
            case .privacyPolicyPressed:  return "SettingsView_PrivacyPolicy_Pressed"
            case .termsOfServicePressed: return "SettingsView_TermsOfService_Pressed"
            case .notificationsStart:    return "SettingsView_Notifications_Start"
            case .notificationsEnable:   return "SettingsView_Notifications_Enable"
            case .notificationsCancel:   return "SettingsView_Notifications_Cancel"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .notificationsEnable(isAuthorized: let isAuthorized):
                return ["is_authorized": isAuthorized]
            default:
                return nil
            }
        }

        var type: LogType { .analytic }
    }

}
