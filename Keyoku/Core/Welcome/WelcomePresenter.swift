//
//  WelcomePresenter.swift
//  
//
//  
//
import SwiftUI

/// Welcome screen presenter that routes users to onboarding or sign-in.
///
/// New users tap "Get Started" to begin onboarding. Returning users tap "Sign In"
/// to authenticate via Apple/Google — existing accounts skip onboarding and go straight to the tab bar.
@Observable
@MainActor
class WelcomePresenter {
    
    private let interactor: WelcomeInteractor
    private let router: WelcomeRouter

    init(interactor: WelcomeInteractor, router: WelcomeRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: WelcomeDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: WelcomeDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onGetStartedPressed() {
        interactor.trackEvent(event: Event.getStartedPressed)
        router.showOnboardingCompletedView(delegate: OnboardingCompletedDelegate())
    }
        
    private func handleDidSignIn(isNewUser: Bool) {
        interactor.trackEvent(event: Event.didSignIn(isNewUser: isNewUser))
        
        if isNewUser {
            // Do nothing, user goes through onboarding
        } else {
            // Push into tabbar view
            router.switchToCoreModule()
        }
    }
    
    func onSignInPressed() {
        interactor.trackEvent(event: Event.signInPressed)
        
        let delegate = CreateAccountDelegate(
            title: String(localized: "Sign in"),
            subtitle: String(localized: "Connect to an existing account."),
            onDidSignIn: { isNewUser in
                self.handleDidSignIn(isNewUser: isNewUser)
            }
        )
        router.showCreateAccountView(delegate: delegate, onDismiss: nil)
    }

}

extension WelcomePresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: WelcomeDelegate)
        case onDisappear(delegate: WelcomeDelegate)
        case didSignIn(isNewUser: Bool)
        case getStartedPressed
        case signInPressed
        
        var eventName: String {
            switch self {
            case .onAppear:           return "WelcomeView_Appear"
            case .onDisappear:        return "WelcomeView_Disappear"
            case .getStartedPressed:  return "WelcomeView_GetStarted_Pressed"
            case .didSignIn:          return "WelcomeView_DidSignIn"
            case .signInPressed:      return "WelcomeView_SignIn_Pressed"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .didSignIn(isNewUser: let isNewUser):
                return [
                    "is_new_user": isNewUser
                ]
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
