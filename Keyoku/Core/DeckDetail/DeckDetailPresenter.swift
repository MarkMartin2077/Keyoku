//
//  DeckDetailPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import PDFKit

@Observable
@MainActor
class DeckDetailPresenter {

    enum SourceInputMode: String, CaseIterable {
        case text, pdf

        var displayName: String {
            switch self {
            case .text: return String(localized: "Paste Text")
            case .pdf: return String(localized: "Upload PDF")
            }
        }
    }

    let interactor: DeckDetailInteractor
    private let router: DeckDetailRouter
    let deckId: String

    let deckName: String
    let deckColor: DeckColor

    var deck: DeckModel? {
        interactor.getDeck(id: deckId)
    }

    var flashcards: [FlashcardModel] {
        deck?.flashcards ?? []
    }

    var deckImageUrlString: String? {
        deck?.displayImageUrlString
    }

    // MARK: - Generation State

    var sourceText: String = ""
    var cardCount: Int = 10
    var sourceInputMode: SourceInputMode = .text
    var pdfFileName: String?
    var pdfPageCount: Int?
    var isExtractingPDF: Bool = false
    var pdfError: String?

    var isGeneratingCards: Bool = false
    var isGenerationComplete: Bool = false
    var generationStartTime: Date?
    var flashcardProgress: Int = 0
    var flashcardTotal: Int = 0
    var flashcardStatusText: String?
    var flashcardSkippedBatches: Int = 0
    var flashcardItemsGenerated: Int = 0
    var streamedFlashcards: [FlashcardModel] = []
    var generatedFlashcardCount: Int = 0

    private static let charsPerCard: Int = 150

    var maxCardCount: Int {
        let trimmedLength = sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count
        let rawMax = trimmedLength / Self.charsPerCard
        let roundedToStep = (rawMax / 5) * 5
        return min(max(roundedToStep, 10), 50)
    }

    var canGenerate: Bool {
        !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isGeneratingCards
    }

    var skippedBatches: Int {
        flashcardSkippedBatches
    }

    var hasProgress: Bool {
        flashcardTotal > 0
    }

    // MARK: - Init

    init(interactor: DeckDetailInteractor, router: DeckDetailRouter, deck: DeckModel) {
        self.interactor = interactor
        self.router = router
        self.deckId = deck.deckId
        self.deckName = deck.name
        self.deckColor = deck.color
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: DeckDetailDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: DeckDetailDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    // MARK: - Practice

    func onPracticePressed() {
        guard let deck = deck else { return }
        interactor.trackEvent(event: Event.onPracticePressed)
        router.showPracticeView(deck: deck)
    }

    // MARK: - Manual Card Management

    func onAddCardPressed(question: String, answer: String) {
        interactor.trackEvent(event: Event.onAddCardPressed)

        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuestion.isEmpty, !trimmedAnswer.isEmpty else {
            interactor.trackEvent(event: Event.onAddCardEmptyFields)
            return
        }

        do {
            try interactor.addFlashcard(question: trimmedQuestion, answer: trimmedAnswer, toDeckId: deckId)
            interactor.trackEvent(event: Event.onAddCardSuccess)
        } catch {
            interactor.trackEvent(event: Event.onAddCardFail(error: error))
            router.showAlert(error: error)
        }
    }

    func onDeleteFlashcards(at indexSet: IndexSet) {
        for index in indexSet {
            let flashcard = flashcards[index]
            interactor.trackEvent(event: Event.onDeleteCardPressed(flashcard: flashcard))

            do {
                try interactor.deleteFlashcard(id: flashcard.flashcardId, fromDeckId: deckId)
                interactor.trackEvent(event: Event.onDeleteCardSuccess(flashcardId: flashcard.flashcardId))
            } catch {
                interactor.trackEvent(event: Event.onDeleteCardFail(error: error))
                router.showAlert(error: error)
            }
        }
    }

    // MARK: - Generation Actions

    func onGenerateSheetOpened() {
        interactor.trackEvent(event: Event.onGenerateSheetOpened)
        resetGenerationState()
        sourceText = ""
        sourceInputMode = .text
        pdfFileName = nil
        pdfPageCount = nil
        pdfError = nil
        cardCount = 10
    }

    func onSourceInputModeChanged(_ mode: SourceInputMode) {
        interactor.trackEvent(event: Event.onSourceInputModeChanged(mode: mode.rawValue))
        sourceInputMode = mode
        pdfError = nil

        if mode == .text {
            pdfFileName = nil
            pdfPageCount = nil
            sourceText = ""
        }
    }

    func onPDFFileSelected(result: Result<URL, Error>) {
        pdfError = nil

        switch result {
        case .success(let url):
            let fileName = url.lastPathComponent
            interactor.trackEvent(event: Event.onPDFFileSelected(fileName: fileName))
            isExtractingPDF = true

            do {
                let text = try extractText(from: url)
                sourceText = text
                pdfFileName = fileName
                isExtractingPDF = false
                interactor.trackEvent(event: Event.onPDFExtractSuccess(fileName: fileName, pageCount: pdfPageCount ?? 0, textLength: text.count))
            } catch {
                isExtractingPDF = false
                pdfError = error.localizedDescription
                interactor.trackEvent(event: Event.onPDFExtractFail(error: error))
            }

        case .failure(let error):
            pdfError = error.localizedDescription
            interactor.trackEvent(event: Event.onPDFPickerFail(error: error))
        }
    }

    func onClearPDF() {
        interactor.trackEvent(event: Event.onPDFCleared)
        sourceText = ""
        pdfFileName = nil
        pdfPageCount = nil
        pdfError = nil
    }

    func onCardCountChanged(_ count: Int) {
        interactor.trackEvent(event: Event.onCardCountChanged(count: count))
        cardCount = count
    }

    func clampCardCountIfNeeded() {
        if cardCount > maxCardCount {
            cardCount = maxCardCount
        }
    }

    func onGenerateCardsPressed() {
        interactor.trackEvent(event: Event.onGenerateCardsPressed(sourceTextLength: sourceText.count, cardCount: cardCount, sourceInputMode: sourceInputMode.rawValue))

        guard canGenerate else { return }

        resetGenerationState()
        isGeneratingCards = true
        generationStartTime = Date()

        Task {
            do {
                try await performAddGeneration()
                handleGenerationSuccess()
            } catch {
                interactor.trackEvent(event: Event.onGenerateCardsFail(error: error))
                isGeneratingCards = false
                router.showSimpleAlert(title: String(localized: "Generation Failed"), subtitle: error.localizedDescription)
            }
        }
    }

    func onGenerateCardsSuccessDismissed() {
        interactor.trackEvent(event: Event.onGenerateCardsSuccessDismissed)
        isGenerationComplete = false
    }

    // MARK: - Generation Helpers

    private func resetGenerationState() {
        isGeneratingCards = false
        isGenerationComplete = false
        generationStartTime = nil
        flashcardProgress = 0
        flashcardTotal = 0
        flashcardStatusText = nil
        flashcardSkippedBatches = 0
        flashcardItemsGenerated = 0
        streamedFlashcards = []
        generatedFlashcardCount = 0
    }

    private func handleGenerationSuccess() {
        isGeneratingCards = false
        isGenerationComplete = true
        interactor.playHaptic(option: .achievementUnlocked())
    }

    private func performAddGeneration() async throws {
        try await generateFlashcards()
        let newCards = streamedFlashcards
        generatedFlashcardCount = newCards.count
        interactor.trackEvent(event: Event.onGenerateCardsSuccess(count: newCards.count))

        guard let currentDeck = deck else { return }

        let flashcardsWithDeckId = newCards.map { card in
            FlashcardModel(flashcardId: card.flashcardId, question: card.question, answer: card.answer, deckId: currentDeck.deckId)
        }

        let updatedSourceText = currentDeck.sourceText.isEmpty ? sourceText : currentDeck.sourceText

        let updatedDeck = DeckModel(
            deckId: currentDeck.deckId,
            name: currentDeck.name,
            color: currentDeck.color,
            imageUrl: currentDeck.imageUrl,
            sourceText: updatedSourceText,
            createdAt: currentDeck.createdAt,
            flashcards: currentDeck.flashcards + flashcardsWithDeckId
        )

        try interactor.updateDeck(updatedDeck)
    }

    // MARK: - PDF Extraction

    private func extractText(from url: URL) throws -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: url) else {
            throw AppError("Could not read the PDF. The file may be damaged or password-protected.")
        }

        guard document.pageCount > 0 else {
            throw AppError("The PDF has no pages.")
        }

        pdfPageCount = document.pageCount

        var pages: [String] = []
        for index in 0..<document.pageCount {
            if let page = document.page(at: index), let text = page.string, !text.isEmpty {
                pages.append(text)
            }
        }

        let fullText = pages.joined(separator: "\n\n")

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError("No readable text found in the PDF. It may contain only images or scanned content.")
        }

        return fullText
    }
}

// MARK: - Events

extension DeckDetailPresenter {

    enum Event: LoggableEvent {
        // Lifecycle
        case onAppear(delegate: DeckDetailDelegate)
        case onDisappear(delegate: DeckDetailDelegate)
        // Practice
        case onPracticePressed
        // Manual card management
        case onAddCardPressed
        case onAddCardEmptyFields
        case onAddCardSuccess
        case onAddCardFail(error: Error)
        case onDeleteCardPressed(flashcard: FlashcardModel)
        case onDeleteCardSuccess(flashcardId: String)
        case onDeleteCardFail(error: Error)
        // Generation
        case onGenerateSheetOpened
        case onSourceInputModeChanged(mode: String)
        case onPDFFileSelected(fileName: String)
        case onPDFExtractSuccess(fileName: String, pageCount: Int, textLength: Int)
        case onPDFExtractFail(error: Error)
        case onPDFPickerFail(error: Error)
        case onPDFCleared
        case onCardCountChanged(count: Int)
        case onGenerateCardsPressed(sourceTextLength: Int, cardCount: Int, sourceInputMode: String)
        case onGenerateCardsBatchStart(batchNumber: Int, totalBatches: Int, cardCount: Int)
        case onGenerateCardsSuccess(count: Int)
        case onGenerateCardsFail(error: Error)
        case onGenerateCardsSuccessDismissed

        var eventName: String {
            switch self {
            case .onAppear:                     return "DeckDetailView_Appear"
            case .onDisappear:                  return "DeckDetailView_Disappear"
            case .onPracticePressed:            return "DeckDetailView_Practice_Pressed"
            case .onAddCardPressed:             return "DeckDetailView_AddCard_Pressed"
            case .onAddCardEmptyFields:         return "DeckDetailView_AddCard_EmptyFields"
            case .onAddCardSuccess:             return "DeckDetailView_AddCard_Success"
            case .onAddCardFail:                return "DeckDetailView_AddCard_Fail"
            case .onDeleteCardPressed:          return "DeckDetailView_DeleteCard_Pressed"
            case .onDeleteCardSuccess:          return "DeckDetailView_DeleteCard_Success"
            case .onDeleteCardFail:             return "DeckDetailView_DeleteCard_Fail"
            case .onGenerateSheetOpened:        return "DeckDetailView_GenerateSheet_Opened"
            case .onSourceInputModeChanged:     return "DeckDetailView_SourceInputMode_Changed"
            case .onPDFFileSelected:            return "DeckDetailView_PDF_Selected"
            case .onPDFExtractSuccess:          return "DeckDetailView_PDF_Extract_Success"
            case .onPDFExtractFail:             return "DeckDetailView_PDF_Extract_Fail"
            case .onPDFPickerFail:              return "DeckDetailView_PDF_Picker_Fail"
            case .onPDFCleared:                 return "DeckDetailView_PDF_Cleared"
            case .onCardCountChanged:           return "DeckDetailView_CardCount_Changed"
            case .onGenerateCardsPressed:       return "DeckDetailView_GenerateCards_Pressed"
            case .onGenerateCardsBatchStart:    return "DeckDetailView_GenerateCards_Batch_Start"
            case .onGenerateCardsSuccess:       return "DeckDetailView_GenerateCards_Success"
            case .onGenerateCardsFail:          return "DeckDetailView_GenerateCards_Fail"
            case .onGenerateCardsSuccessDismissed: return "DeckDetailView_GenerateCards_SuccessDismissed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onDeleteCardPressed(flashcard: let flashcard):
                return flashcard.eventParameters
            case .onDeleteCardSuccess(flashcardId: let id):
                return ["flashcard_id": id]
            case .onAddCardFail(error: let error), .onDeleteCardFail(error: let error), .onPDFExtractFail(error: let error), .onPDFPickerFail(error: let error), .onGenerateCardsFail(error: let error):
                return error.eventParameters
            case .onSourceInputModeChanged(mode: let mode):
                return ["source_input_mode": mode]
            case .onPDFFileSelected(fileName: let name):
                return ["file_name": name]
            case .onPDFExtractSuccess(fileName: let name, pageCount: let pages, textLength: let length):
                return ["file_name": name, "page_count": pages, "text_length": length]
            case .onCardCountChanged(count: let count):
                return ["card_count": count]
            case .onGenerateCardsPressed(sourceTextLength: let length, cardCount: let count, sourceInputMode: let mode):
                return ["source_text_length": length, "card_count": count, "source_input_mode": mode]
            case .onGenerateCardsBatchStart(batchNumber: let batch, totalBatches: let total, cardCount: let cards):
                return ["batch_number": batch, "total_batches": total, "batch_card_count": cards]
            case .onGenerateCardsSuccess(count: let count):
                return ["card_count": count]
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onAddCardFail, .onDeleteCardFail, .onPDFExtractFail, .onPDFPickerFail, .onGenerateCardsFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
