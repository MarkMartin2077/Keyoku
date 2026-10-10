//
//  DeckDetailInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol DeckDetailInteractor: GlobalInteractor {
    func getDeck(id: String) -> DeckModel?
    func addFlashcard(question: String, answer: String, toDeckId: String) throws
    func deleteFlashcard(id: String, fromDeckId: String) throws
    func updateDeck(_ deck: DeckModel) throws
    func saveDeckImage(data: Data) throws -> String
    var generationAvailability: GenerationAvailability { get }
    func prewarmGeneration()
    func generateFlashcards(from text: String, count: Int, avoiding existingQuestions: [String]) -> AsyncThrowingStream<GenerationEvent, Error>
    func extractPDFText(from url: URL) async throws -> (text: String, pageCount: Int)

    // Quizzes
    func quizzes(forDeckId deckId: String) -> [QuizModel]
    func deleteQuiz(id: String) throws
    var quizGenerationAvailability: GenerationAvailability { get }
    func prewarmQuizGeneration()
    func canMakeQuiz(sourceLength: Int) -> Bool
    var minQuizQuestionCount: Int { get }
    var minQuizSourceLength: Int { get }
    func maxQuizQuestionCount(sourceLength: Int) -> Int
    func defaultQuizQuestionCount(sourceLength: Int) -> Int
    func generateQuiz(
        for deck: DeckModel,
        questionCount: Int,
        onProgress: @escaping @MainActor (QuizGenerationProgress) -> Void
    ) async throws -> QuizModel
}

extension CoreInteractor: DeckDetailInteractor { }
