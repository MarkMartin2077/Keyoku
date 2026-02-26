//
//  DeckDetailPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import PDFKit

/// Deck detail presenter that manages a single deck's flashcards, metadata, and AI generation.
///
/// Provides full CRUD for flashcards (add, edit, delete), deck editing (name, color, image),
/// practice session launching, learned-status reset, and on-device AI card generation from
/// pasted text or uploaded PDFs. Generation streams cards in batches with quality filtering.
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

    private let _initialDeckName: String
    private let _initialDeckColor: DeckColor

    var deckName: String {
        deck?.name ?? _initialDeckName
    }

    var deckColor: DeckColor {
        deck?.color ?? _initialDeckColor
    }

    var deck: DeckModel? {
        interactor.getDeck(id: deckId)
    }

    var flashcards: [FlashcardModel] {
        deck?.flashcards ?? []
    }

    var deckImageUrlString: String? {
        deck?.displayImageUrlString
    }

    var learnedCount: Int {
        flashcards.filter(\.isLearned).count
    }

    var stillStudyingCount: Int {
        flashcards.count - learnedCount
    }

    var practiceSubtitle: String {
        if learnedCount > 0 {
            return "\(learnedCount) learned \u{00B7} \(stillStudyingCount) to study"
        }
        return "Study all \(flashcards.count) cards"
    }

    // MARK: - Edit Card State

    var editingFlashcard: FlashcardModel?

    // MARK: - Edit Deck State

    var showEditDeckSheet: Bool = false
    var editDeckName: String = ""
    var editDeckColor: DeckColor = .blue
    var editDeckImage: UIImage?
    var editDeckImageChanged: Bool = false

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
    static let minimumSourceTextLength: Int = 300

    var trimmedSourceTextLength: Int {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    var sourceTextTooShort: Bool {
        trimmedSourceTextLength > 0 && trimmedSourceTextLength < Self.minimumSourceTextLength
    }

    var maxCardCount: Int {
        let rawMax = trimmedSourceTextLength / Self.charsPerCard
        let roundedToStep = (rawMax / 5) * 5
        return min(max(roundedToStep, 10), 50)
    }

    var canGenerate: Bool {
        trimmedSourceTextLength >= Self.minimumSourceTextLength &&
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
        self._initialDeckName = deck.name
        self._initialDeckColor = deck.color
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

    func onResetLearnedStatus() {
        interactor.trackEvent(event: Event.onResetLearnedStatus)
        guard let currentDeck = deck else { return }

        let resetFlashcards = currentDeck.flashcards.map { card in
            FlashcardModel(
                flashcardId: card.flashcardId,
                question: card.question,
                answer: card.answer,
                deckId: card.deckId,
                isLearned: false
            )
        }

        let updatedDeck = DeckModel(
            deckId: currentDeck.deckId,
            name: currentDeck.name,
            color: currentDeck.color,
            imageUrl: currentDeck.imageUrl,
            sourceText: currentDeck.sourceText,
            createdAt: currentDeck.createdAt,
            flashcards: resetFlashcards,
            clickCount: currentDeck.clickCount
        )

        do {
            try interactor.updateDeck(updatedDeck)
            interactor.trackEvent(event: Event.onResetLearnedStatusSuccess(cardCount: resetFlashcards.count))
            interactor.playHaptic(option: .medium)
        } catch {
            interactor.trackEvent(event: Event.onResetLearnedStatusFail(error: error))
            router.showAlert(error: error)
        }
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

    // MARK: - Edit Card

    func onEditCardPressed(flashcard: FlashcardModel) {
        interactor.trackEvent(event: Event.onEditCardPressed(flashcard: flashcard))
        editingFlashcard = flashcard
    }

    func onSaveEditedCard(flashcardId: String, question: String, answer: String) {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuestion.isEmpty, !trimmedAnswer.isEmpty else { return }
        guard let currentDeck = deck else { return }

        let updatedFlashcards = currentDeck.flashcards.map { card in
            if card.flashcardId == flashcardId {
                return FlashcardModel(flashcardId: flashcardId, question: trimmedQuestion, answer: trimmedAnswer, deckId: currentDeck.deckId, isLearned: card.isLearned)
            }
            return card
        }

        let updatedDeck = DeckModel(
            deckId: currentDeck.deckId,
            name: currentDeck.name,
            color: currentDeck.color,
            imageUrl: currentDeck.imageUrl,
            sourceText: currentDeck.sourceText,
            createdAt: currentDeck.createdAt,
            flashcards: updatedFlashcards,
            clickCount: currentDeck.clickCount
        )

        do {
            try interactor.updateDeck(updatedDeck)
            editingFlashcard = nil
            interactor.trackEvent(event: Event.onEditCardSaved(flashcardId: flashcardId))
        } catch {
            interactor.trackEvent(event: Event.onEditCardSaveFail(error: error))
            router.showAlert(error: error)
        }
    }

    func onCancelEditCard() {
        interactor.trackEvent(event: Event.onEditCardCancelled)
        editingFlashcard = nil
    }

    // MARK: - Edit Deck

    func onEditDeckPressed() {
        guard let currentDeck = deck else { return }
        interactor.trackEvent(event: Event.onEditDeckPressed)
        editDeckName = currentDeck.name
        editDeckColor = currentDeck.color
        editDeckImageChanged = false

        if let imageFileURL = currentDeck.imageFileURL,
           let data = try? Data(contentsOf: imageFileURL) {
            editDeckImage = UIImage(data: data)
        } else {
            editDeckImage = nil
        }

        showEditDeckSheet = true
    }

    func onEditDeckColorSelected(_ color: DeckColor) {
        interactor.trackEvent(event: Event.onEditDeckColorChanged(color: color.rawValue))
        editDeckColor = color
    }

    func onEditDeckImageDataLoaded(_ data: Data) {
        interactor.trackEvent(event: Event.onEditDeckImageSelected)
        editDeckImage = UIImage(data: data)
        editDeckImageChanged = true
    }

    func onEditDeckRemoveImage() {
        interactor.trackEvent(event: Event.onEditDeckImageRemoved)
        editDeckImage = nil
        editDeckImageChanged = true
    }

    func onSaveEditedDeck() {
        let trimmedName = editDeckName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard let currentDeck = deck else { return }

        var imageUrl = currentDeck.imageUrl

        if editDeckImageChanged {
            if let image = editDeckImage, let data = image.jpegData(compressionQuality: 0.8) {
                do {
                    imageUrl = try interactor.saveDeckImage(data: data)
                } catch {
                    interactor.trackEvent(event: Event.onEditDeckSaveFail(error: error))
                    router.showAlert(error: error)
                    return
                }
            } else {
                imageUrl = nil
            }
        }

        let updatedDeck = DeckModel(
            deckId: currentDeck.deckId,
            name: trimmedName,
            color: editDeckColor,
            imageUrl: imageUrl,
            sourceText: currentDeck.sourceText,
            createdAt: currentDeck.createdAt,
            flashcards: currentDeck.flashcards,
            clickCount: currentDeck.clickCount
        )

        do {
            try interactor.updateDeck(updatedDeck)
            showEditDeckSheet = false
            interactor.trackEvent(event: Event.onEditDeckSaved)
        } catch {
            interactor.trackEvent(event: Event.onEditDeckSaveFail(error: error))
            router.showAlert(error: error)
        }
    }

    func onCancelEditDeck() {
        interactor.trackEvent(event: Event.onEditDeckCancelled)
        showEditDeckSheet = false
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

        guard !newCards.isEmpty else {
            throw AppError(String(localized: "No flashcards could be generated from this text. Try pasting actual study material like notes, a textbook excerpt, or an article."))
        }

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
            flashcards: currentDeck.flashcards + flashcardsWithDeckId,
            clickCount: currentDeck.clickCount
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
        case onResetLearnedStatus
        case onResetLearnedStatusSuccess(cardCount: Int)
        case onResetLearnedStatusFail(error: Error)
        // Manual card management
        case onAddCardPressed
        case onAddCardEmptyFields
        case onAddCardSuccess
        case onAddCardFail(error: Error)
        case onDeleteCardPressed(flashcard: FlashcardModel)
        case onDeleteCardSuccess(flashcardId: String)
        case onDeleteCardFail(error: Error)
        // Edit card
        case onEditCardPressed(flashcard: FlashcardModel)
        case onEditCardSaved(flashcardId: String)
        case onEditCardSaveFail(error: Error)
        case onEditCardCancelled
        // Edit deck
        case onEditDeckPressed
        case onEditDeckSaved
        case onEditDeckSaveFail(error: Error)
        case onEditDeckCancelled
        case onEditDeckColorChanged(color: String)
        case onEditDeckImageSelected
        case onEditDeckImageRemoved
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
            case .onResetLearnedStatus:         return "DeckDetailView_ResetLearned_Pressed"
            case .onResetLearnedStatusSuccess:  return "DeckDetailView_ResetLearned_Success"
            case .onResetLearnedStatusFail:     return "DeckDetailView_ResetLearned_Fail"
            case .onAddCardPressed:             return "DeckDetailView_AddCard_Pressed"
            case .onAddCardEmptyFields:         return "DeckDetailView_AddCard_EmptyFields"
            case .onAddCardSuccess:             return "DeckDetailView_AddCard_Success"
            case .onAddCardFail:                return "DeckDetailView_AddCard_Fail"
            case .onDeleteCardPressed:          return "DeckDetailView_DeleteCard_Pressed"
            case .onDeleteCardSuccess:          return "DeckDetailView_DeleteCard_Success"
            case .onDeleteCardFail:             return "DeckDetailView_DeleteCard_Fail"
            case .onEditCardPressed:             return "DeckDetailView_EditCard_Pressed"
            case .onEditCardSaved:               return "DeckDetailView_EditCard_Saved"
            case .onEditCardSaveFail:            return "DeckDetailView_EditCard_SaveFail"
            case .onEditCardCancelled:           return "DeckDetailView_EditCard_Cancelled"
            case .onEditDeckPressed:             return "DeckDetailView_EditDeck_Pressed"
            case .onEditDeckSaved:               return "DeckDetailView_EditDeck_Saved"
            case .onEditDeckSaveFail:            return "DeckDetailView_EditDeck_SaveFail"
            case .onEditDeckCancelled:           return "DeckDetailView_EditDeck_Cancelled"
            case .onEditDeckColorChanged:        return "DeckDetailView_EditDeck_ColorChanged"
            case .onEditDeckImageSelected:       return "DeckDetailView_EditDeck_ImageSelected"
            case .onEditDeckImageRemoved:        return "DeckDetailView_EditDeck_ImageRemoved"
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
            case .onEditCardPressed(flashcard: let flashcard):
                return flashcard.eventParameters
            case .onEditCardSaved(flashcardId: let id):
                return ["flashcard_id": id]
            case .onEditDeckColorChanged(color: let color):
                return ["color": color]
            case .onResetLearnedStatusSuccess(cardCount: let count):
                return ["card_count": count]
            case .onAddCardFail(error: let error), .onDeleteCardFail(error: let error), .onEditCardSaveFail(error: let error),
                 .onEditDeckSaveFail(error: let error), .onPDFExtractFail(error: let error), .onPDFPickerFail(error: let error),
                 .onGenerateCardsFail(error: let error), .onResetLearnedStatusFail(error: let error):
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
            case .onAddCardFail, .onDeleteCardFail, .onEditCardSaveFail, .onEditDeckSaveFail, .onPDFExtractFail, .onPDFPickerFail, .onGenerateCardsFail, .onResetLearnedStatusFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
