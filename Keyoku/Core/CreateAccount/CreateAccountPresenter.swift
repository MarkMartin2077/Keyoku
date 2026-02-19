//
//  CreateAccountPresenter.swift
//  
//
//  
//
import SwiftUI
import SignInAppleAsync

/// Account creation presenter that handles Apple and Google sign-in.
///
/// Before authenticating, snapshots any anonymous decks so they can be migrated to the
/// new account after sign-in. Handles credential conflicts (error 17025) with a dedicated alert
/// and restores the anonymous session if sign-in fails.
@Observable
@MainActor
class CreateAccountPresenter {
    
    private let interactor: CreateAccountInteractor
    private let router: CreateAccountRouter

    init(interactor: CreateAccountInteractor, router: CreateAccountRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: CreateAccountDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: CreateAccountDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onSignInApplePressed(delegate: CreateAccountDelegate) {
        interactor.trackEvent(event: Event.appleAuthStart)

        // Snapshot anonymous state before auth changes the UID
        let anonymousDecks = interactor.decks
        let oldUid = interactor.auth?.uid
        let wasAnonymous = interactor.auth?.isAnonymous == true

        Task {
            do {
                // Sign out anonymous auth to prevent the package's link() call from
                // consuming the Apple token and failing with credentialAlreadyInUse.
                if wasAnonymous {
                    try interactor.signOutAuthOnly()
                }

                let result = try await interactor.signInApple()
                interactor.trackEvent(event: Event.appleAuthSuccess(user: result.user, isNewUser: result.isNewUser))

                try await interactor.logIn(user: result.user, isNewUser: result.isNewUser)
                interactor.trackEvent(event: Event.appleAuthLoginSuccess(user: result.user, isNewUser: result.isNewUser))

                // Push anonymous decks to the new account's remote storage
                if let oldUid, oldUid != result.user.uid, !anonymousDecks.isEmpty {
                    interactor.trackEvent(event: Event.migrationStart(count: anonymousDecks.count))
                    interactor.migrateDecks(anonymousDecks)
                    interactor.trackEvent(event: Event.migrationSuccess(count: anonymousDecks.count))
                }

                delegate.onDidSignIn?(result.isNewUser)
                router.dismissScreen()
            } catch {
                // Restore anonymous session so the user isn't left signed out
                if wasAnonymous {
                    _ = try? await interactor.signInAnonymously()
                }

                interactor.trackEvent(event: Event.appleAuthFail(error: error))

                if (error as NSError).code == 17025 {
                    showCredentialConflictAlert()
                } else {
                    router.showAlert(error: error)
                }
            }
        }
    }

    private func showCredentialConflictAlert() {
        router.showAlert(
            .alert,
            title: "Apple Account Already Linked",
            subtitle: "This Apple ID is already associated with another account. Try signing in with Google instead, or continue without an account.\n\nTo unlink this Apple ID, go to Settings > Apple ID > Sign-In & Security > Sign in with Apple, and remove this app.",
            buttons: {
                AnyView(
                    Group {
                        Button("OK") { }
                    }
                )
            }
        )
    }

    func onSignInGooglePressed(delegate: CreateAccountDelegate) {
        interactor.trackEvent(event: Event.googleAuthStart)

        // Snapshot anonymous state before auth changes the UID
        let anonymousDecks = interactor.decks
        let oldUid = interactor.auth?.uid
        let wasAnonymous = interactor.auth?.isAnonymous == true

        Task {
            do {
                // Sign out anonymous auth to prevent the package's link() call from
                // consuming the Google token and failing with credentialAlreadyInUse.
                if wasAnonymous {
                    try interactor.signOutAuthOnly()
                }

                let result = try await interactor.signInGoogle()
                interactor.trackEvent(event: Event.googleAuthSuccess(user: result.user, isNewUser: result.isNewUser))

                try await interactor.logIn(user: result.user, isNewUser: result.isNewUser)
                interactor.trackEvent(event: Event.googleAuthLoginSuccess(user: result.user, isNewUser: result.isNewUser))

                // Push anonymous decks to the new account's remote storage
                if let oldUid, oldUid != result.user.uid, !anonymousDecks.isEmpty {
                    interactor.trackEvent(event: Event.migrationStart(count: anonymousDecks.count))
                    interactor.migrateDecks(anonymousDecks)
                    interactor.trackEvent(event: Event.migrationSuccess(count: anonymousDecks.count))
                }

                delegate.onDidSignIn?(result.isNewUser)
                router.dismissScreen()
            } catch {
                // Restore anonymous session so the user isn't left signed out
                if wasAnonymous {
                   _ = try? await interactor.signInAnonymously()
                }

                interactor.trackEvent(event: Event.googleAuthFail(error: error))
                router.showAlert(error: error)
            }
        }
    }

}

extension CreateAccountPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: CreateAccountDelegate)
        case onDisappear(delegate: CreateAccountDelegate)
        case appleAuthStart
        case appleAuthSuccess(user: UserAuthInfo, isNewUser: Bool)
        case appleAuthLoginSuccess(user: UserAuthInfo, isNewUser: Bool)
        case appleAuthFail(error: Error)
        case googleAuthStart
        case googleAuthSuccess(user: UserAuthInfo, isNewUser: Bool)
        case googleAuthLoginSuccess(user: UserAuthInfo, isNewUser: Bool)
        case googleAuthFail(error: Error)
        case migrationStart(count: Int)
        case migrationSuccess(count: Int)

        var eventName: String {
            switch self {
            case .onAppear:                return "CreateAccountView_Appear"
            case .onDisappear:             return "CreateAccountView_Disappear"
            case .appleAuthStart:          return "CreateAccountView_AppleAuth_Start"
            case .appleAuthSuccess:        return "CreateAccountView_AppleAuth_Success"
            case .appleAuthLoginSuccess:   return "CreateAccountView_AppleAuth_LoginSuccess"
            case .appleAuthFail:           return "CreateAccountView_AppleAuth_Fail"
            case .googleAuthStart:          return "CreateAccountView_GoogleAuth_Start"
            case .googleAuthSuccess:        return "CreateAccountView_GoogleAuth_Success"
            case .googleAuthLoginSuccess:   return "CreateAccountView_GoogleAuth_LoginSuccess"
            case .googleAuthFail:           return "CreateAccountView_GoogleAuth_Fail"
            case .migrationStart:           return "CreateAccountView_Migration_Start"
            case .migrationSuccess:         return "CreateAccountView_Migration_Success"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .appleAuthSuccess(user: let user, isNewUser: let isNewUser),
                .appleAuthLoginSuccess(user: let user, isNewUser: let isNewUser),
                .googleAuthSuccess(user: let user, isNewUser: let isNewUser),
                .googleAuthLoginSuccess(user: let user, isNewUser: let isNewUser)
                :
                var dict = user.eventParameters
                dict["is_new_user"] = isNewUser
                return dict
            case .appleAuthFail(error: let error), .googleAuthFail(error: let error):
                return error.eventParameters
            case .migrationStart(count: let count), .migrationSuccess(count: let count):
                return ["deck_count": count]
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .appleAuthFail, .googleAuthFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
    
}
