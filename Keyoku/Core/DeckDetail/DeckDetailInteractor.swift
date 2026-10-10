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
}

extension CoreInteractor: DeckDetailInteractor { }
