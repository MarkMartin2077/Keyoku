//
//  CreateDeckPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import UIKit
import PDFKit
import FoundationModels

/// New deck creation presenter that supports AI-generated and empty deck workflows.
///
/// Users can generate flashcards from pasted text or uploaded PDFs using on-device AI,
/// or create an empty deck to add cards manually later. Handles deck naming, color selection,
/// cover image, and a first-deck celebration flow for new users.
@Observable
@MainActor
class CreateDeckPresenter {

    enum CreationMode: String, CaseIterable {
        case generate, empty

        var displayName: String {
            switch self {
            case .generate: return String(localized: "Generate with AI")
            case .empty: return String(localized: "Start Empty")
            }
        }
    }

    enum SourceInputMode: String, CaseIterable {
        case text, pdf

        var displayName: String {
            switch self {
            case .text: return String(localized: "Paste Text")
            case .pdf: return String(localized: "Upload PDF")
            }
        }
    }

    let interactor: CreateDeckInteractor
    private let router: CreateDeckRouter

    var creationMode: CreationMode = .generate
    var cardCount: Int = 10
    var deckName: String = ""
    var selectedColor: DeckColor = .blue
    var selectedImage: UIImage?
    var sourceText: String = ""
    var isGenerating: Bool = false
    var isGenerationComplete: Bool = false
    var generationStartTime: Date?
    var estimatedSecondsRemaining: Int?

    // Flashcard progress
    var flashcardProgress: Int = 0
    var flashcardTotal: Int = 0
    var flashcardStatusText: String?
    var flashcardSkippedBatches: Int = 0
    var flashcardItemsGenerated: Int = 0

    // Streaming state — items appear here as they're generated
    var streamedFlashcards: [FlashcardModel] = []

    // Generation results
    var generatedFlashcardCount: Int = 0

    // First deck celebration
    var showFirstDeckCelebration: Bool = false
    private var wasFirstDeck: Bool = false

    private var hasCreatedFirstDeck: Bool {
        interactor.currentUser?.didCreateFirstDeck == true
    }

    var skippedBatches: Int {
        flashcardSkippedBatches
    }

    var hasProgress: Bool {
        flashcardTotal > 0
    }

    var sourceInputMode: SourceInputMode = .text
    var pdfFileName: String?
    var pdfPageCount: Int?
    var isExtractingPDF: Bool = false
    var pdfError: String?

    private static let charsPerCard: Int = 150
    static let minimumSourceTextLength: Int = 150

    var trimmedSourceTextLength: Int {
        sourceText.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    var maxCardCount: Int {
        let rawMax = trimmedSourceTextLength / Self.charsPerCard
        let roundedToStep = (rawMax / 5) * 5 // Round down to nearest step of 5
        return min(max(roundedToStep, 10), 50)
    }

    var sourceTextTooShort: Bool {
        trimmedSourceTextLength > 0 && trimmedSourceTextLength < Self.minimumSourceTextLength
    }

    var canGenerate: Bool {
        !deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        trimmedSourceTextLength >= Self.minimumSourceTextLength &&
        !isGenerating
    }

    var canCreateEmpty: Bool {
        !deckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(interactor: CreateDeckInteractor, router: CreateDeckRouter) {
        self.interactor = interactor
        self.router = router
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: CreateDeckDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: CreateDeckDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    // MARK: - Settings Actions

    func onColorSelected(_ color: DeckColor) {
        interactor.trackEvent(event: Event.onColorSelected(color: color))
        selectedColor = color
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

    func onCreationModeChanged(_ mode: CreationMode) {
        interactor.trackEvent(event: Event.onCreationModeChanged(mode: mode.rawValue))
        creationMode = mode
    }

    // MARK: - Image Actions

    func onImageDataLoaded(_ data: Data) {
        interactor.trackEvent(event: Event.onImageSelected)
        if let image = UIImage(data: data) {
            selectedImage = image
        }
    }

    func onRemoveImage() {
        interactor.trackEvent(event: Event.onImageRemoved)
        selectedImage = nil
    }

    // MARK: - Source Input Actions

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

    // MARK: - Primary Actions

    func onCancelPressed() {
        interactor.trackEvent(event: Event.onCancelPressed)
        router.dismiss()
    }

    func onGeneratePressed() {
        interactor.trackEvent(event: Event.onGeneratePressed(sourceTextLength: sourceText.count, cardCount: cardCount, sourceInputMode: sourceInputMode.rawValue))

        guard canGenerate else { return }

        wasFirstDeck = !hasCreatedFirstDeck && interactor.decks.isEmpty
        resetGenerationState()

        Task {
            do {
                try await performGeneration()
                handleGenerationSuccess()
            } catch {
                interactor.trackEvent(event: Event.onGenerateFail(error: error))
                isGenerating = false
                router.showSimpleAlert(title: String(localized: "Generation Failed"), subtitle: error.localizedDescription)
            }
        }
    }

    func onSuccessDismissPressed() {
        interactor.trackEvent(event: Event.onSuccessDismissPressed)
        isGenerationComplete = false

        if wasFirstDeck {
            showFirstDeckCelebration = true
        } else {
            router.dismiss()
        }
    }

    func onFirstDeckCelebrationDismissed() {
        interactor.trackEvent(event: Event.onFirstDeckCelebrationDismissed)
        showFirstDeckCelebration = false
        router.dismiss()

        Task {
            try? await interactor.saveFirstDeckCreated()
        }
    }

    private func resetGenerationState() {
        isGenerating = true
        isGenerationComplete = false
        generationStartTime = Date()
        estimatedSecondsRemaining = nil
        flashcardProgress = 0
        flashcardTotal = 0
        flashcardStatusText = nil
        flashcardSkippedBatches = 0
        flashcardItemsGenerated = 0
        streamedFlashcards = []
        generatedFlashcardCount = 0
    }

    private func handleGenerationSuccess() {
        isGenerating = false
        isGenerationComplete = true
        interactor.playHaptic(option: .achievementUnlocked())
    }

    private func performGeneration() async throws {
        let trimmedName = deckName.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedImageUrl = try saveImageIfNeeded()

        try await generateFlashcards()
        let flashcards = streamedFlashcards

        guard !flashcards.isEmpty else {
            throw AppError(String(localized: "No flashcards could be generated from this text. Try pasting actual study material like notes, a textbook excerpt, or an article."))
        }

        generatedFlashcardCount = flashcards.count
        interactor.trackEvent(event: Event.onGenerateSuccess(cardCount: flashcards.count))

        try interactor.createDeck(
            name: trimmedName,
            color: selectedColor,
            imageUrl: savedImageUrl,
            sourceText: sourceText,
            flashcards: flashcards
        )
    }

    func onCreateEmptyPressed() {
        interactor.trackEvent(event: Event.onCreateEmptyPressed)

        guard canCreateEmpty else { return }

        let isFirstDeck = !hasCreatedFirstDeck && interactor.decks.isEmpty

        do {
            let savedImageUrl = try saveImageIfNeeded()

            try interactor.createDeck(
                name: deckName.trimmingCharacters(in: .whitespacesAndNewlines),
                color: selectedColor,
                imageUrl: savedImageUrl,
                sourceText: ""
            )

            interactor.trackEvent(event: Event.onCreateEmptySuccess)
            interactor.playHaptic(option: .success)

            if isFirstDeck {
                wasFirstDeck = true
                showFirstDeckCelebration = true
            } else {
                router.dismiss()
            }
        } catch {
            interactor.trackEvent(event: Event.onCreateEmptyFail(error: error))
            router.showAlert(error: error)
        }
    }

    // MARK: - Helpers

    private func saveImageIfNeeded() throws -> String? {
        guard let selectedImage, let imageData = selectedImage.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        return try interactor.saveDeckImage(data: imageData)
    }

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
