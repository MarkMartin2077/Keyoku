//
//  PracticeRouter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/10/26.
//

import SwiftUI

@MainActor
protocol PracticeRouter: GlobalRouter {
    func showPaywallView(delegate: PaywallDelegate)
}

extension CoreRouter: PracticeRouter { }
