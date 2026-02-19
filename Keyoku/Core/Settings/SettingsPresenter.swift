//
//  SettingsPresenter.swift
//
//
//
//
import SwiftUI
import SwiftfulUtilities

/// Settings presenter that provides links to system settings and legal documents.
///
/// Opens notification settings, privacy policy, and terms of service URLs.
/// Also manages the app ratings flow with a yes/no enjoyment prompt before requesting a review.
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

    func onNotificationsPressed() {
        interactor.trackEvent(event: Event.notificationsPressed)

        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
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

    func onRatingsButtonPressed() {
        interactor.trackEvent(event: Event.ratingsPressed)

        func onEnjoyingAppYesPressed() {
            interactor.trackEvent(event: Event.ratingsYesPressed)
            router.dismissModal()
            AppStoreRatingsHelper.requestRatingsReview()
        }

        func onEnjoyingAppNoPressed() {
            interactor.trackEvent(event: Event.ratingsNoPressed)
            router.dismissModal()
        }

        router.showRatingsModal(
            onYesPressed: onEnjoyingAppYesPressed,
            onNoPressed: onEnjoyingAppNoPressed
        )
    }

}

extension SettingsPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case notificationsPressed
        case privacyPolicyPressed
        case termsOfServicePressed
        case ratingsPressed
        case ratingsYesPressed
        case ratingsNoPressed

        var eventName: String {
            switch self {
            case .onAppear:                     return "SettingsView_Appear"
            case .onDisappear:                  return "SettingsView_Disappear"
            case .notificationsPressed:         return "SettingsView_Notifications_Pressed"
            case .privacyPolicyPressed:         return "SettingsView_PrivacyPolicy_Pressed"
            case .termsOfServicePressed:        return "SettingsView_TermsOfService_Pressed"
            case .ratingsPressed:               return "SettingsView_Ratings_Pressed"
            case .ratingsYesPressed:            return "SettingsView_RatingsYes_Pressed"
            case .ratingsNoPressed:             return "SettingsView_RatingsNo_Pressed"
            }
        }

        var parameters: [String: Any]? {
            nil
        }

        var type: LogType {
            .analytic
        }
    }

}
