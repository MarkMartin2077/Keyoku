//
//  DeckDetailRouter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol DeckDetailRouter: GlobalRouter {
    func showPracticeView(deck: DeckModel, cardLimit: Int?)
    func showReviewDueView(deck: DeckModel)
    func showQuizPlayView(quiz: QuizModel, deckColor: DeckColor)
    func showDeleteQuizAlert(quizTitle: String, onDeletePressed: @escaping @MainActor @Sendable () -> Void)
    func showSimpleAlert(title: String, subtitle: String?)
}

extension CoreRouter: DeckDetailRouter {

    func showDeleteQuizAlert(quizTitle: String, onDeletePressed: @escaping @MainActor @Sendable () -> Void) {
        router.showAlert(
            .alert,
            title: String(localized: "Delete \u{201C}\(quizTitle)\u{201D}?"),
            subtitle: String(localized: "This quiz and its best score will be deleted."),
            buttons: {
                AnyView(
                    Group {
                        Button("Delete", role: .destructive) {
                            onDeletePressed()
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

}
