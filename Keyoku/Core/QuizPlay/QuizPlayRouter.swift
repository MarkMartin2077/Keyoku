//
//  QuizPlayRouter.swift
//  Keyoku
//

import SwiftUI

@MainActor
protocol QuizPlayRouter: GlobalRouter {
    func showLeaveQuizAlert(
        onLeavePressed: @escaping @MainActor @Sendable () -> Void,
        onStayPressed: @escaping @MainActor @Sendable () -> Void
    )
    func dismissScreen()
}

extension CoreRouter: QuizPlayRouter {

    func showLeaveQuizAlert(
        onLeavePressed: @escaping @MainActor @Sendable () -> Void,
        onStayPressed: @escaping @MainActor @Sendable () -> Void
    ) {
        router.showAlert(
            .alert,
            title: "Leave this quiz?",
            subtitle: "Your answers so far won't be saved.",
            buttons: {
                AnyView(
                    Group {
                        Button("Leave", role: .destructive) {
                            onLeavePressed()
                        }
                        Button("Keep Going", role: .cancel) {
                            onStayPressed()
                        }
                    }
                )
            }
        )
    }

}
