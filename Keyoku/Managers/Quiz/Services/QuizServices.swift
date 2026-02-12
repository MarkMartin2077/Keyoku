//
//  QuizServices.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import Foundation

@MainActor
protocol QuizServices {
    var local: QuizService { get }
    var remote: RemoteQuizService { get }
}

@MainActor
struct MockQuizServices: QuizServices {
    let local: QuizService
    let remote: RemoteQuizService

    init(quizzes: [QuizModel] = QuizModel.mocks) {
        self.local = MockQuizPersistence(quizzes: quizzes)
        self.remote = MockRemoteQuizService(quizzes: quizzes)
    }
}

@MainActor
struct ProductionQuizServices: QuizServices {
    let local: QuizService = SwiftDataQuizPersistence()
    let remote: RemoteQuizService = FirebaseQuizService()
}
