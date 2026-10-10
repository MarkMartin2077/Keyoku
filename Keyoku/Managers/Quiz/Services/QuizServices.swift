//
//  QuizServices.swift
//  Keyoku
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

    /// Seeds both stores with the same quizzes, like `MockFlashcardServices`.
    init(quizzes: [QuizModel] = QuizModel.mocks) {
        self.local = MockQuizPersistence(quizzes: quizzes)
        self.remote = MockRemoteQuizService(quizzes: quizzes)
    }

    /// Lets tests seed local and remote separately and keep a handle on each.
    init(local: QuizService, remote: RemoteQuizService) {
        self.local = local
        self.remote = remote
    }
}

@MainActor
struct ProductionQuizServices: QuizServices {
    let local: QuizService = SwiftDataQuizPersistence()
    let remote: RemoteQuizService = FirebaseQuizService()
}
