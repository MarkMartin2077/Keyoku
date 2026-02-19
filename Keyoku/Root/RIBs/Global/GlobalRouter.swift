//
//  GlobalRouter.swift
//  Keyoku
//
//  
//
import SwiftUI

@MainActor
protocol GlobalRouter {
    var router: AnyRouter { get }
}

extension GlobalRouter {
    
    func dismissScreen() {
        router.dismissScreen()
    }
    
    func dismissEnvironment() {
        router.dismissEnvironment()
    }
    
    func dismissPushStack() {
        router.dismissPushStack()
    }
    
    func dismissModal() {
        router.dismissModal()
    }
    
    func showNextScreen() throws {
        try router.tryShowNextScreen()
    }
    
    func showNextScreenOrDismissEnvironment() {
        router.showNextScreenOrDismissEnvironment()
    }
    
    func showNextScreenOrDismissPushStack() {
        router.showNextScreenOrDismissPushStack()
    }
    
    func showAlert(_ option: AlertStyle, title: String, subtitle: String?, buttons: (@Sendable () -> AnyView)?) {
        router.showAlert(option, title: title, subtitle: subtitle, buttons: {
            buttons?()
        })
    }
    
    func showSimpleAlert(title: String, subtitle: String?) {
        router.showAlert(.alert, title: title, subtitle: subtitle, buttons: { })
    }
    
    func showAlert(error: Error) {
        router.showAlert(.alert, title: "Error", subtitle: error.localizedDescription, buttons: { })
    }
    
    func showPushNotificationModal(onEnablePressed: @escaping () -> Void, onCancelPressed: @escaping () -> Void) {
        router.showModal(
            transition: .move(edge: .bottom), backgroundColor: Color.black.opacity(0.6),
            destination: {
                CustomModalView(
                    title: "Enable push notifications?",
                    subtitle: "We'll send you reminders and updates!",
                    primaryButtonTitle: "Enable",
                    primaryButtonAction: {
                        onEnablePressed()
                    },
                    secondaryButtonTitle: "Cancel",
                    secondaryButtonAction: {
                        onCancelPressed()
                    }
                )
            }
        )
    }
    
    func showRatingsModal(onYesPressed: @escaping () -> Void, onNoPressed: @escaping () -> Void) {
        router.showModal(transition: .fade, backgroundColor: Color.black.opacity(0.6)) {
            CustomModalView(
                title: "Are you enjoying Keyoku?",
                subtitle: "We'd love to hear your feedback!",
                primaryButtonTitle: "Yes",
                primaryButtonAction: {
                    onYesPressed()
                },
                secondaryButtonTitle: "No",
                secondaryButtonAction: {
                    onNoPressed()
                }
            )
        }
    }
    
    func showFirstDeckPremiumPromptModal(onSeeOfferPressed: @escaping () -> Void, onDismissPressed: @escaping () -> Void) {
        router.showModal(transition: .move(edge: .bottom), backgroundColor: Color.black.opacity(0.6)) {
            CustomModalView(
                title: "Great start!",
                subtitle: "Unlock unlimited decks with a free 3-day trial of Premium.",
                primaryButtonTitle: "See the offer",
                primaryButtonAction: {
                    onSeeOfferPressed()
                },
                secondaryButtonTitle: "Maybe later",
                secondaryButtonAction: {
                    onDismissPressed()
                }
            )
        }
    }

    func showDeckMasteredPremiumPromptModal(onSeeOfferPressed: @escaping () -> Void, onDismissPressed: @escaping () -> Void) {
        router.showModal(transition: .move(edge: .bottom), backgroundColor: Color.black.opacity(0.6)) {
            CustomModalView(
                title: "You're on a roll!",
                subtitle: "Keep the momentum going — try Premium free for 3 days.",
                primaryButtonTitle: "See the offer",
                primaryButtonAction: {
                    onSeeOfferPressed()
                },
                secondaryButtonTitle: "Maybe later",
                secondaryButtonAction: {
                    onDismissPressed()
                }
            )
        }
    }

    func dismissAlert() {
        router.dismissAlert()
    }
}
