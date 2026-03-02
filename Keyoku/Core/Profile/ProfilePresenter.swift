import SwiftUI

/// Profile presenter that displays user info, study stats, and account management actions.
///
/// Shows profile name/email/image, streak count, deck/card statistics, and premium status.
/// Provides sign out, delete account (with reauthentication), upgrade to premium,
/// manage subscription, and account creation for anonymous users.
@Observable
@MainActor
class ProfilePresenter {

    private let interactor: ProfileInteractor
    private let router: ProfileRouter

    private(set) var isAnonymousUser: Bool = false

    // MARK: - Profile Data

    var profileName: String? {
        interactor.currentUser?.commonNameCalculated
    }

    var profileEmail: String? {
        interactor.currentUser?.emailCalculated
    }

    var profileImageUrl: String? {
        interactor.currentUser?.profileImageNameCalculated
    }

    // MARK: - Stats

    var currentStreak: Int {
        interactor.currentStreakData.currentStreak ?? 0
    }

    var totalDecks: Int {
        interactor.decks.count
    }

    var totalCards: Int {
        interactor.decks.reduce(0) { $0 + $1.flashcards.count }
    }

    var learnedCards: Int {
        interactor.decks.reduce(0) { total, deck in
            total + deck.flashcards.filter { $0.isLearned }.count
        }
    }

    // MARK: - Premium

    var isPremium: Bool {
        interactor.isPremium
    }

    // MARK: - Reminders

    var isReminderEnabled: Bool = false
    var reminderDate: Date = Date()

    init(interactor: ProfileInteractor, router: ProfileRouter) {
        self.interactor = interactor
        self.router = router
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: ProfileDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        setAnonymousAccountStatus()
        isReminderEnabled = interactor.isReminderEnabled
        reminderDate = dateFromReminderPrefs()
    }

    func onViewDisappear(delegate: ProfileDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    private func setAnonymousAccountStatus() {
        isAnonymousUser = interactor.auth?.isAnonymous == true
    }

    // MARK: - Actions

    func onSettingsButtonPressed() {
        interactor.trackEvent(event: Event.settingsPressed)
        router.showSettingsView()
    }

    func onReminderToggled(isOn: Bool) {
        interactor.trackEvent(event: Event.reminderToggled(isOn: isOn))

        Task {
            if isOn {
                let canRequest = await interactor.canRequestPushAuthorization()
                if canRequest {
                    _ = try? await interactor.requestPushAuthorization()
                }
            }
            try? await interactor.setReminderEnabled(isOn)
            isReminderEnabled = interactor.isReminderEnabled
        }
    }

    func onReminderTimeChanged(date: Date) {
        interactor.trackEvent(event: Event.reminderTimeChanged)
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 10
        let minute = components.minute ?? 0
        interactor.setReminderTime(hour: hour, minute: minute)
        reminderDate = date
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

    func onSignOutPressed() {
        interactor.trackEvent(event: Event.signOutStart)

        Task {
            do {
                try await interactor.signOut()
                interactor.trackEvent(event: Event.signOutSuccess)
                await dismissAndSwitchToOnboarding()
            } catch {
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.signOutFail(error: error))
            }
        }
    }

    func onDeleteAccountPressed() {
        interactor.trackEvent(event: Event.deleteAccountStart)

        router.showAlert(
            .alert,
            title: String(localized: "Delete Account?"),
            subtitle: String(localized: "This action is permanent and cannot be undone. Your data will be deleted from our server forever."),
            buttons: {
                AnyView(
                    Button("Delete", role: .destructive, action: {
                        self.showDeleteAccountReauthAlert()
                    })
                )
            }
        )
    }

    private func showDeleteAccountReauthAlert() {
        router.showAlert(
            .alert,
            title: String(localized: "Reauthentication Required"),
            subtitle: String(localized: "As a safety precaution in order to delete your account, you must first sign again."),
            buttons: {
                AnyView(
                    Button("Delete", role: .destructive, action: {
                        self.onDeleteAccountConfirmed()
                    })
                )
            }
        )
    }

    private func onDeleteAccountConfirmed() {
        interactor.trackEvent(event: Event.deleteAccountStartConfirm)

        Task {
            do {
                try await interactor.deleteAccount()
                interactor.trackEvent(event: Event.deleteAccountSuccess)
                await dismissAndSwitchToOnboarding()
            } catch {
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.deleteAccountFail(error: error))
            }
        }
    }

    func onUpgradeToPremiumPressed() {
        interactor.trackEvent(event: Event.upgradeToPremiumPressed)
        router.showPaywallView(delegate: PaywallDelegate(source: "profile_upgrade"))
    }

    func onManageSubscriptionPressed() {
        interactor.trackEvent(event: Event.manageSubscriptionPressed)
    }

    func onCreateAccountPressed() {
        interactor.trackEvent(event: Event.createAccountPressed)

        let delegate = CreateAccountDelegate()
        router.showCreateAccountView(delegate: delegate, onDismiss: {
            self.setAnonymousAccountStatus()
        })
    }

    private func dateFromReminderPrefs() -> Date {
        let hour = interactor.reminderHour
        let minute = interactor.reminderMinute
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func dismissAndSwitchToOnboarding() async {
        router.dismissScreen()
        try? await Task.sleep(for: .seconds(1))
        router.switchToOnboardingModule()
    }
}

extension ProfilePresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: ProfileDelegate)
        case onDisappear(delegate: ProfileDelegate)
        case settingsPressed
        case signOutStart
        case signOutSuccess
        case signOutFail(error: Error)
        case deleteAccountStart
        case deleteAccountStartConfirm
        case deleteAccountSuccess
        case deleteAccountFail(error: Error)
        case createAccountPressed
        case upgradeToPremiumPressed
        case manageSubscriptionPressed
        case reminderToggled(isOn: Bool)
        case reminderTimeChanged
        case ratingsPressed
        case ratingsYesPressed
        case ratingsNoPressed

        var eventName: String {
            switch self {
            case .onAppear:                     return "ProfileView_Appear"
            case .onDisappear:                  return "ProfileView_Disappear"
            case .settingsPressed:              return "ProfileView_Settings_Pressed"
            case .signOutStart:                 return "ProfileView_SignOut_Start"
            case .signOutSuccess:               return "ProfileView_SignOut_Success"
            case .signOutFail:                  return "ProfileView_SignOut_Fail"
            case .deleteAccountStart:           return "ProfileView_DeleteAccount_Start"
            case .deleteAccountStartConfirm:    return "ProfileView_DeleteAccount_StartConfirm"
            case .deleteAccountSuccess:         return "ProfileView_DeleteAccount_Success"
            case .deleteAccountFail:            return "ProfileView_DeleteAccount_Fail"
            case .createAccountPressed:         return "ProfileView_CreateAccount_Pressed"
            case .upgradeToPremiumPressed:      return "ProfileView_UpgradePremium_Pressed"
            case .manageSubscriptionPressed:    return "ProfileView_ManageSubscription_Pressed"
            case .reminderToggled:              return "ProfileView_Reminder_Toggled"
            case .reminderTimeChanged:          return "ProfileView_ReminderTime_Changed"
            case .ratingsPressed:               return "ProfileView_Ratings_Pressed"
            case .ratingsYesPressed:            return "ProfileView_RatingsYes_Pressed"
            case .ratingsNoPressed:             return "ProfileView_RatingsNo_Pressed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .signOutFail(error: let error), .deleteAccountFail(error: let error):
                return error.eventParameters
            case .reminderToggled(isOn: let isOn):
                return ["is_on": isOn]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .signOutFail, .deleteAccountFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
