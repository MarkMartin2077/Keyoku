//
//  CreateDeckPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import UIKit

/// New deck creation presenter that supports AI-generated and empty deck workflows.
///
/// Users can generate flashcards from pasted text or uploaded PDFs using Apple Intelligence,
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
    private(set) var progress = GenerationProgressState()
    private var generationTask: Task<Void, Never>?

    // First deck celebration
    var showFirstDeckCelebration: Bool = false
    private var wasFirstDeck: Bool = false

    private var hasCreatedFirstDeck: Bool {
        interactor.currentUser?.didCreateFirstDeck == true
    }

    var sourceInputMode: SourceInputMode = .text
    var pdfFileName: String?
    var pdfPageCount: Int?
    var isExtractingPDF: Bool = false
    var pdfError: String?

    private static let charsPerCard: Int = 150
    static let minimumSourceTextLength: Int = 300

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

    var unavailableReason: UnavailableReason? {
        if case .unavailable(let reason) = interactor.generationAvailability {
            return reason
        }
        return nil
    }

    var generatedFlashcardCount: Int {
        progress.cards.count
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
        if unavailableReason == nil {
            interactor.prewarmGeneration()
        }
    }

    func onViewDisappear(delegate: CreateDeckDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
        generationTask?.cancel()
    }

    func onOpenSettingsPressed() {
        interactor.trackEvent(event: Event.onOpenSettingsPressed)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
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

            Task {
                defer { isExtractingPDF = false }
                do {
                    let extraction = try await interactor.extractPDFText(from: url)
                    sourceText = extraction.text
                    pdfFileName = fileName
                    pdfPageCount = extraction.pageCount
                    interactor.trackEvent(event: Event.onPDFExtractSuccess(fileName: fileName, pageCount: extraction.pageCount, textLength: extraction.text.count))
                } catch {
                    pdfError = error.localizedDescription
                    interactor.trackEvent(event: Event.onPDFExtractFail(error: error))
                }
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
        isGenerating = true
        isGenerationComplete = false
        progress = GenerationProgressState()

        generationTask = Task {
            do {
                for try await event in interactor.generateFlashcards(from: sourceText, count: cardCount, avoiding: []) {
                    progress.apply(event)
                }
                guard !Task.isCancelled else { return }
                interactor.trackEvent(event: Event.onGenerateSuccess(cardCount: progress.cards.count))
            } catch {
                guard !Task.isCancelled else { return }
                let failure = error as? GenerationFailure ?? .other(String(describing: error))
                interactor.trackEvent(event: Event.onGenerateFail(failure: failure))
                isGenerating = false
                router.showSimpleAlert(title: String(localized: "Generation Failed"), subtitle: failure.userMessage)
                return
            }
            saveGeneratedDeck()
        }
    }

    func onCancelGenerationPressed() {
        interactor.trackEvent(event: Event.onCancelGenerationPressed(cardsSoFar: progress.cards.count))
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        progress = GenerationProgressState()
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

    private func saveGeneratedDeck() {
        do {
            try interactor.createDeck(
                name: deckName.trimmingCharacters(in: .whitespacesAndNewlines),
                color: selectedColor,
                imageUrl: try saveImageIfNeeded(),
                sourceText: sourceText,
                flashcards: progress.cards
            )
            isGenerating = false
            isGenerationComplete = true
            interactor.playHaptic(option: .achievementUnlocked())
        } catch {
            interactor.trackEvent(event: Event.onSaveDeckFail(error: error))
            isGenerating = false
            router.showSimpleAlert(
                title: String(localized: "Couldn't Save Deck"),
                subtitle: String(localized: "Your flashcards were generated but the deck couldn't be saved. Please try again.")
            )
        }
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
}
