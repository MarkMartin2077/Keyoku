//
//  QuizRouter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@MainActor
protocol QuizRouter: GlobalRouter {

}

extension CoreRouter: QuizRouter { }
