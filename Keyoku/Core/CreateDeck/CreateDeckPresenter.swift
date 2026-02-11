//
//  CreateDeckPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import FoundationModels

@Observable
@MainActor
class CreateDeckPresenter {
    
    private let interactor: CreateDeckInteractor
    private let router: CreateDeckRouter
    
    var deckName: String = ""
    var selectedColor: DeckColor = .blue
    var sourceText: String = ""
    var isGenerating: Bool = false
    
    var canGenerate: Bool {
        !deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }
    
    init(interactor: CreateDeckInteractor, router: CreateDeckRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: CreateDeckDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: CreateDeckDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onColorSelected(_ color: DeckColor) {
        interactor.trackEvent(event: Event.onColorSelected(color: color))
        selectedColor = color
    }
    
    func onCancelPressed() {
        interactor.trackEvent(event: Event.onCancelPressed)
        router.dismiss()
    }
    
    func onGeneratePressed() {
        interactor.trackEvent(event: Event.onGeneratePressed(sourceTextLength: sourceText.count))
        
        guard canGenerate else { return }
        
        isGenerating = true
        
        Task {
            do {
                let flashcards = try await generateFlashcards()
                interactor.trackEvent(event: Event.onGenerateSuccess(cardCount: flashcards.count))
                
                try interactor.createDeck(
                    name: deckName.trimmingCharacters(in: .whitespacesAndNewlines),
                    color: selectedColor,
                    sourceText: sourceText,
                    flashcards: flashcards
                )
                
                isGenerating = false
                router.dismiss()
                
            } catch {
                interactor.trackEvent(event: Event.onGenerateFail(error: error))
                isGenerating = false
            }
        }
    }
    
    private func generateFlashcards() async throws -> [FlashcardModel] {
        let session = LanguageModelSession()
        
        let prompt = """
        Generate flashcards from the following text. Create cards that help \
        students learn effectively using these techniques:
        - Key definitions and terminology
        - Cause and effect relationships
        - Compare and contrast important concepts
        - Important dates, timelines, or sequences
        - Formulas, rules, or principles
        - Key facts and their significance

        Each card should have a clear, specific question and a concise but \
        complete answer.

        Text:
        \(sourceText)
        """
        
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedFlashcards.self
        )
        
        return response.content.toModels()
    }
}

extension CreateDeckPresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: CreateDeckDelegate)
        case onDisappear(delegate: CreateDeckDelegate)
        case onColorSelected(color: DeckColor)
        case onCancelPressed
        case onGeneratePressed(sourceTextLength: Int)
        case onGenerateSuccess(cardCount: Int)
        case onGenerateFail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:             return "CreateDeckView_Appear"
            case .onDisappear:          return "CreateDeckView_Disappear"
            case .onColorSelected:      return "CreateDeckView_ColorSelected"
            case .onCancelPressed:      return "CreateDeckView_Cancel"
            case .onGeneratePressed:    return "CreateDeckView_Generate_Pressed"
            case .onGenerateSuccess:    return "CreateDeckView_Generate_Success"
            case .onGenerateFail:       return "CreateDeckView_Generate_Fail"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onColorSelected(color: let color):
                return ["color": color.rawValue]
            case .onGeneratePressed(sourceTextLength: let length):
                return ["source_text_length": length]
            case .onGenerateSuccess(cardCount: let count):
                return ["card_count": count]
            case .onGenerateFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .onGenerateFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
