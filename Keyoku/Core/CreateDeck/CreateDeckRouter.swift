//
//  CreateDeckRouter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol CreateDeckRouter: GlobalRouter {
    func dismiss()
}

extension CoreRouter: CreateDeckRouter {
    
    func dismiss() {
        router.dismissScreen()
    }
    
}
