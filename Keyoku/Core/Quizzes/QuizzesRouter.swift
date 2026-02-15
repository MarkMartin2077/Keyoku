//
//  QuizzesRouter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

@MainActor
protocol QuizzesRouter: GlobalRouter {
    func showQuizDetailView(quiz: QuizModel)
    func showCreateContentView(defaultContentType: CreateDeckPresenter.ContentType?)
}

extension CoreRouter: QuizzesRouter {

    func showCreateContentView(defaultContentType: CreateDeckPresenter.ContentType?) {
        let delegate = CreateDeckDelegate(defaultContentType: defaultContentType)
        router.showScreen(.sheet) { router in
            NavigationStack {
                builder.createDeckView(router: router, delegate: delegate)
            }
        }
    }

}
