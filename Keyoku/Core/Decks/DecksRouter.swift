//
//  DecksRouter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol DecksRouter: GlobalRouter {
    func showDeckDetailView(deck: DeckModel)
    func showCreateContentView(onDismiss: (() -> Void)?)
    func showPaywallView(delegate: PaywallDelegate)
    func showDeleteDeckAlert(deckName: String, onConfirm: @escaping @MainActor @Sendable () -> Void)
}

extension CoreRouter: DecksRouter {

    func showDeckDetailView(deck: DeckModel) {
        let delegate = DeckDetailDelegate(deck: deck)
        router.showScreen(.push) { router in
            builder.deckDetailView(router: router, delegate: delegate)
        }
    }

    func showDeleteDeckAlert(deckName: String, onConfirm: @escaping @MainActor @Sendable () -> Void) {
        router.showAlert(
            .alert,
            title: "Delete \"\(deckName)\"?",
            subtitle: "This deck and all its cards will be permanently deleted.",
            buttons: {
                AnyView(
                    Button("Delete", role: .destructive) {
                        onConfirm()
                    }
                )
            }
        )
    }

}
