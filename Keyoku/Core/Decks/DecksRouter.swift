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
    func showCreateDeckView()
}

extension CoreRouter: DecksRouter {
    
    func showDeckDetailView(deck: DeckModel) {
        let delegate = DeckDetailDelegate(deck: deck)
        router.showScreen(.push) { router in
            builder.deckDetailView(router: router, delegate: delegate)
        }
    }
    
    func showCreateDeckView() {
        let delegate = CreateDeckDelegate()
        router.showScreen(.sheet) { router in
            NavigationStack {
                builder.createDeckView(router: router, delegate: delegate)
            }
        }
    }
    
}
