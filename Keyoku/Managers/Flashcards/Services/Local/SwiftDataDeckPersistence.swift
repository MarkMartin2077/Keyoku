//
//  SwiftDataDeckPersistence.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import Foundation
import SwiftData

@MainActor
struct SwiftDataDeckPersistence: DeckService {
    private let container: ModelContainer
    
    private var mainContext: ModelContext {
        container.mainContext
    }
    
    init() {
        // swiftlint:disable:next force_try
        self.container = try! ModelContainer(for: DeckEntity.self, FlashcardEntity.self)
    }
    
    func getAllDecks() throws -> [DeckModel] {
        let descriptor = FetchDescriptor<DeckEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let entities = try mainContext.fetch(descriptor)
        return entities.map { $0.toModel() }
    }
    
    func getDeck(id: String) throws -> DeckModel? {
        let predicate = #Predicate<DeckEntity> { $0.id == id }
        var descriptor = FetchDescriptor<DeckEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        let entities = try mainContext.fetch(descriptor)
        return entities.first?.toModel()
    }
    
    func saveDeck(deck: DeckModel) throws {
        // Check if deck already exists
        let predicate = #Predicate<DeckEntity> { $0.id == deck.deckId }
        var descriptor = FetchDescriptor<DeckEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        let existingEntities = try mainContext.fetch(descriptor)
        
        if let existingEntity = existingEntities.first {
            // Update existing deck
            existingEntity.name = deck.name
            existingEntity.color = deck.color
            existingEntity.imageUrl = deck.imageUrl
            existingEntity.sourceText = deck.sourceText
            existingEntity.createdAt = deck.createdAt
            
            // Remove old flashcards
            for flashcard in existingEntity.flashcards {
                mainContext.delete(flashcard)
            }
            existingEntity.flashcards.removeAll()
            
            // Add new flashcards
            for card in deck.flashcards {
                let flashcardEntity = FlashcardEntity(
                    id: card.flashcardId,
                    question: card.question,
                    answer: card.answer
                )
                flashcardEntity.deck = existingEntity
                mainContext.insert(flashcardEntity)
            }
        } else {
            // Create new deck
            let deckEntity = DeckEntity(
                id: deck.deckId,
                name: deck.name,
                color: deck.color,
                imageUrl: deck.imageUrl,
                sourceText: deck.sourceText,
                createdAt: deck.createdAt
            )
            mainContext.insert(deckEntity)
            
            // Create and insert each flashcard
            for card in deck.flashcards {
                let flashcardEntity = FlashcardEntity(
                    id: card.flashcardId,
                    question: card.question,
                    answer: card.answer
                )
                flashcardEntity.deck = deckEntity
                mainContext.insert(flashcardEntity)
            }
        }
        
        try mainContext.save()
    }
    
    func deleteDeck(id: String) throws {
        let predicate = #Predicate<DeckEntity> { $0.id == id }
        var descriptor = FetchDescriptor<DeckEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        let entities = try mainContext.fetch(descriptor)
        
        if let entity = entities.first {
            mainContext.delete(entity)
            try mainContext.save()
        }
    }
    
    func addFlashcard(flashcard: FlashcardModel, toDeckId: String) throws {
        let predicate = #Predicate<DeckEntity> { $0.id == toDeckId }
        var descriptor = FetchDescriptor<DeckEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        let entities = try mainContext.fetch(descriptor)
        
        guard let deckEntity = entities.first else {
            throw DeckPersistenceError.deckNotFound
        }
        
        let flashcardEntity = FlashcardEntity(
            id: flashcard.flashcardId,
            question: flashcard.question,
            answer: flashcard.answer
        )
        flashcardEntity.deck = deckEntity
        mainContext.insert(flashcardEntity)
        
        try mainContext.save()
    }
    
    func deleteFlashcard(id: String) throws {
        let predicate = #Predicate<FlashcardEntity> { $0.id == id }
        var descriptor = FetchDescriptor<FlashcardEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        let entities = try mainContext.fetch(descriptor)
        
        if let entity = entities.first {
            mainContext.delete(entity)
            try mainContext.save()
        }
    }
}

enum DeckPersistenceError: LocalizedError {
    case deckNotFound
    
    var errorDescription: String? {
        switch self {
        case .deckNotFound:
            return "Deck not found"
        }
    }
}
