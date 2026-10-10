//
//  CreateDeckInteractor.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

@MainActor
protocol CreateDeckInteractor: GlobalInteractor {
    var decks: [DeckModel] { get }
    var currentUser: UserModel? { get }
    func createDeck(name: String, color: DeckColor, imageUrl: String?, sourceText: String) throws
    func createDeck(name: String, color: DeckColor, imageUrl: String?, sourceText: String, flashcards: [FlashcardModel]) throws
    func saveDeckImage(data: Data) throws -> String
    func saveFirstDeckCreated() async throws
    var generationAvailability: GenerationAvailability { get }
    func prewarmGeneration()
    func generateFlashcards(from text: String, count: Int, avoiding existingQuestions: [String]) -> AsyncThrowingStream<GenerationEvent, Error>
    func extractPDFText(from url: URL) async throws -> (text: String, pageCount: Int)
}

extension CoreInteractor: CreateDeckInteractor { }
