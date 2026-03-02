//
//  DeckDetailRouter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol DeckDetailRouter: GlobalRouter {
    func showPracticeView(deck: DeckModel)
    func showReviewDueView(deck: DeckModel)
}

extension CoreRouter: DeckDetailRouter { }
