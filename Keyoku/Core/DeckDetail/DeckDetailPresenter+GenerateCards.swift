//
//  DeckDetailPresenter+GenerateCards.swift
//  Keyoku
//

import SwiftUI
import UIKit

extension DeckDetailPresenter {

    func onGenerateSheetOpened() {
        interactor.trackEvent(event: Event.onGenerateSheetOpened)
        generationTask?.cancel()
        isGeneratingCards = false
        isGenerationComplete = false
        progress = GenerationProgressState()
        sourceText = ""
        sourceInputMode = .text
        pdfFileName = nil
        pdfPageCount = nil
        pdfError = nil
        cardCount = 10
        if unavailableReason == nil {
            interactor.prewarmGeneration()
        }
    }

    func onOpenSettingsPressed() {
        interactor.trackEvent(event: Event.onOpenSettingsPressed)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
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

        isGeneratingCards = true
        isGenerationComplete = false
        progress = GenerationProgressState()
        let existingQuestions = flashcards.map(\.question)

        generationTask = Task {
            do {
                for try await event in interactor.generateFlashcards(from: sourceText, count: cardCount, avoiding: existingQuestions) {
                    progress.apply(event)
                }
                guard !Task.isCancelled else { return }
                interactor.trackEvent(event: Event.onGenerateCardsSuccess(count: progress.cards.count))
            } catch {
                guard !Task.isCancelled else { return }
                let failure = error as? GenerationFailure ?? .other(String(describing: error))
                interactor.trackEvent(event: Event.onGenerateCardsFail(failure: failure))
                isGeneratingCards = false
                router.showSimpleAlert(title: String(localized: "Generation Failed"), subtitle: failure.userMessage)
                return
            }
            saveGeneratedCards()
        }
    }

    func onCancelGenerationPressed() {
        interactor.trackEvent(event: Event.onCancelGenerationPressed(cardsSoFar: progress.cards.count))
        generationTask?.cancel()
        generationTask = nil
        isGeneratingCards = false
        progress = GenerationProgressState()
    }

    func onGenerateCardsSuccessDismissed() {
        interactor.trackEvent(event: Event.onGenerateCardsSuccessDismissed)
        isGenerationComplete = false
    }

    /// The deck's source text after generating more cards: the new text is added after the existing text,
    /// so everything the deck was made from stays available (e.g. for quizzes). Text already in the deck isn't added again.
    static func combinedSourceText(existing: String, new: String) -> String {
        let newText = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newText.isEmpty, !existing.contains(newText) else { return existing }
        guard !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return new }
        return existing + "\n\n" + new
    }

    private func saveGeneratedCards() {
        guard let currentDeck = deck else {
            isGeneratingCards = false
            return
        }

        let newCards = progress.cards.map { card in
            FlashcardModel(flashcardId: card.flashcardId, question: card.question, answer: card.answer, deckId: currentDeck.deckId)
        }
        let updatedDeck = DeckModel(
            deckId: currentDeck.deckId,
            name: currentDeck.name,
            color: currentDeck.color,
            imageUrl: currentDeck.imageUrl,
            sourceText: Self.combinedSourceText(existing: currentDeck.sourceText, new: sourceText),
            createdAt: currentDeck.createdAt,
            flashcards: currentDeck.flashcards + newCards,
            clickCount: currentDeck.clickCount,
            lastStudiedAt: currentDeck.lastStudiedAt
        )

        do {
            try interactor.updateDeck(updatedDeck)
            isGeneratingCards = false
            isGenerationComplete = true
            interactor.playHaptic(option: .achievementUnlocked())
        } catch {
            interactor.trackEvent(event: Event.onSaveGeneratedCardsFail(error: error))
            isGeneratingCards = false
            router.showSimpleAlert(
                title: String(localized: "Couldn't Save Cards"),
                subtitle: String(localized: "Your flashcards were generated but couldn't be added to the deck. Please try again.")
            )
        }
    }
}
