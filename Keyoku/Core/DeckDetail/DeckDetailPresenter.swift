//
//  DeckDetailPresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI

/// Deck detail presenter that manages a single deck's flashcards, metadata, and AI generation.
///
/// Provides full CRUD for flashcards (add, edit, delete), deck editing (name, color, image),
/// practice session launching, learned-status reset, and on-device AI card generation from
/// pasted text or uploaded PDFs. Generation streams cards in batches with quality filtering.
///
/// The `flashcards` property is sorted by SRS urgency: overdue cards appear first (oldest
/// due date first), followed by scheduled cards (ascending by due date), with unreviewed
/// new cards last.
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
    let router: DeckDetailRouter
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

    /// Flashcards sorted by SRS urgency for display in the deck detail list.
    ///
    /// Sort order:
    /// 1. **Due** (`dueDate <= now`) — oldest due date first so the most overdue card leads.
    /// 2. **Scheduled** (`dueDate > now`) — ascending by due date.
    /// 3. **New** (`dueDate == nil`) — never reviewed; sorted last as they have no urgency.
    var flashcards: [FlashcardModel] {
        let cards = deck?.flashcards ?? []
        let now = Date()
        return cards.sorted { lhs, rhs in
            let lhsDue = lhs.dueDate.map { $0 <= now } ?? false
            let rhsDue = rhs.dueDate.map { $0 <= now } ?? false
            if lhsDue != rhsDue { return lhsDue }
            switch (lhs.dueDate, rhs.dueDate) {
            case (nil, nil):                        return false
            case (nil, _):                          return false  // new cards sort last
            case (_, nil):                          return true
            case let (lhsDate?, rhsDate?):          return lhsDate < rhsDate
            }
        }
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

    var dueCount: Int {
        flashcards.filter { card in
            guard let dueDate = card.dueDate else { return false }
            return dueDate <= Date()
        }.count
    }

    var hasSRSData: Bool {
        flashcards.contains { $0.dueDate != nil }
    }

    var hasDueReview: Bool {
        hasSRSData && dueCount > 0
    }

    // MARK: - Session Setup State

    var showSessionSetup: Bool = false

    /// Discrete card count options shown in the session setup dialog.
    /// Capped at deck size and always includes a "all cards" option.
    var sessionCardOptions: [Int] {
        let total = flashcards.count
        let candidates = [5, 10, 20]
        return candidates.filter { $0 < total } + [total]
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
        interactor.trackEvent(event: Event.onPracticePressed)
        if flashcards.count <= 5 {
            // Small decks skip the dialog — just start immediately
            onStartSessionPressed(limit: nil)
        } else {
            showSessionSetup = true
        }
    }

    func onStartSessionPressed(limit: Int?) {
        guard let deck = deck else { return }
        showSessionSetup = false
        interactor.trackEvent(event: Event.onSessionStarted(limit: limit, totalCards: flashcards.count))

        let stamped = DeckModel(
            deckId: deck.deckId,
            name: deck.name,
            color: deck.color,
            imageUrl: deck.imageUrl,
            sourceText: deck.sourceText,
            createdAt: deck.createdAt,
            flashcards: deck.flashcards,
            clickCount: deck.clickCount,
            lastStudiedAt: Date()
        )
        try? interactor.updateDeck(stamped)

        router.showPracticeView(deck: deck, cardLimit: limit)
    }

    func onReviewDuePressed() {
        guard let deck = deck else { return }
        interactor.trackEvent(event: Event.onReviewDuePressed(dueCount: dueCount))

        let stamped = DeckModel(
            deckId: deck.deckId,
            name: deck.name,
            color: deck.color,
            imageUrl: deck.imageUrl,
            sourceText: deck.sourceText,
            createdAt: deck.createdAt,
            flashcards: deck.flashcards,
            clickCount: deck.clickCount,
            lastStudiedAt: Date()
        )
        try? interactor.updateDeck(stamped)

        router.showReviewDueView(deck: deck)
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
                isLearned: false,
                repetitions: card.repetitions,
                interval: card.interval,
                easeFactor: card.easeFactor,
                dueDate: card.dueDate,
                stillLearningCount: card.stillLearningCount
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
            clickCount: currentDeck.clickCount,
            lastStudiedAt: currentDeck.lastStudiedAt
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
                return FlashcardModel(
                    flashcardId: flashcardId,
                    question: trimmedQuestion,
                    answer: trimmedAnswer,
                    deckId: currentDeck.deckId,
                    isLearned: card.isLearned,
                    repetitions: card.repetitions,
                    interval: card.interval,
                    easeFactor: card.easeFactor,
                    dueDate: card.dueDate,
                    stillLearningCount: card.stillLearningCount
                )
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
            clickCount: currentDeck.clickCount,
            lastStudiedAt: currentDeck.lastStudiedAt
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
            clickCount: currentDeck.clickCount,
            lastStudiedAt: currentDeck.lastStudiedAt
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
}
