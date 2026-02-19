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
    func showCreateContentView()
    func showPaywallView(delegate: PaywallDelegate)
}

extension CoreRouter: DecksRouter {

    func showDeckDetailView(deck: DeckModel) {
        let delegate = DeckDetailDelegate(deck: deck)
        router.showScreen(.push) { router in
            builder.deckDetailView(router: router, delegate: delegate)
        }
    }

}
