//
//  QuizInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@MainActor
protocol QuizInteractor: GlobalInteractor {

}

extension CoreInteractor: QuizInteractor { }
