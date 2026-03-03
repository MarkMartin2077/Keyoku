//
//  PracticePresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/10/26.
//

import SwiftUI

/// Practice session presenter that drives the flashcard study experience.
///
/// Manages card swiping (learned vs. still learning), undo, shuffle, and practice-again flows.
/// Tracks session completion, persists learned status per card, records streak events,
/// and shows a premium prompt when a free user learns all cards in a deck.
@Observable
@MainActor
class PracticePresenter {

    private let interactor: PracticeInteractor
    private let router: PracticeRouter

    let deckId: String
    let deckName: String
    let deckColor: DeckColor
    let isReviewMode: Bool
    private(set) var flashcards: [FlashcardModel]
    private var cardLimit: Int?
    private var hasRecordedCompletion: Bool = false
    private var isCrossDeckMode: Bool = false
    private var crossDeckSourceIds: Set<String> = []

    // Swipe state
    private(set) var selectedIndex: Int = 0
    var cardOffsets: [String: Bool] = [:]
    var currentSwipeOffset: CGFloat = 0

    // Streak celebration
    var showStreakCelebration: Bool = false
    var newStreakCount: Int = 0

    var currentCard: FlashcardModel? {
        guard !flashcards.isEmpty, selectedIndex < flashcards.count else { return nil }
        return flashcards[selectedIndex]
    }

    var isSessionComplete: Bool {
        !flashcards.isEmpty && selectedIndex >= flashcards.count
    }

    var progress: Double {
        guard !flashcards.isEmpty else { return 0 }
        return Double(selectedIndex) / Double(flashcards.count)
    }

    var learnedCount: Int {
        cardOffsets.values.filter { $0 == true }.count
    }

    var stillLearningCount: Int {
        cardOffsets.values.filter { $0 == false }.count
    }

    var canUndo: Bool {
        selectedIndex > 0
    }

    /// Human-readable label for the next scheduled review date, derived from the
    /// earliest future `dueDate` across all cards in the deck after this session.
    ///
    /// Returns `nil` in cross-deck mode, when no deck is found, or when no cards
    /// have a future due date (e.g., a brand-new deck with no prior SRS data).
    var nextReviewLabel: String? {
        guard !deckId.isEmpty, let deck = interactor.getDeck(id: deckId) else { return nil }
        let now = Date()
        guard let nextDate = deck.flashcards.compactMap(\.dueDate).filter({ $0 > now }).min() else { return nil }
        let fromDay = Calendar.current.startOfDay(for: now)
        let nextDay = Calendar.current.startOfDay(for: nextDate)
        let days = Calendar.current.dateComponents([.day], from: fromDay, to: nextDay).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "In \(days) days"
    }

    var isReminderEnabled: Bool {
        interactor.isReminderEnabled
    }

    init(interactor: PracticeInteractor, router: PracticeRouter, deck: DeckModel, dueOnly: Bool = false, cardLimit: Int? = nil) {
        self.interactor = interactor
        self.router = router
        self.deckId = deck.deckId
        self.deckName = deck.name
        self.deckColor = deck.color
        self.isReviewMode = dueOnly
        let cards = dueOnly ? deck.flashcards.filter { $0.isDue } : deck.flashcards
        let sorted = cards.sorted { lhs, rhs in
            switch (lhs.isDue, rhs.isDue) {
            case (true, false): return true
            case (false, true): return false
            default:
                let lDate = lhs.dueDate ?? .distantPast
                let rDate = rhs.dueDate ?? .distantPast
                return lDate < rDate
            }
        }
        self.flashcards = cardLimit.map { Array(sorted.prefix($0)) } ?? sorted
        self.cardLimit = cardLimit
    }

    init(interactor: PracticeInteractor, router: PracticeRouter, crossDeckCards: [FlashcardModel], decks: [DeckModel]) {
        self.interactor = interactor
        self.router = router
        self.deckId = ""
        self.deckName = "Still Learning"
        self.deckColor = .blue
        self.isReviewMode = false
        self.isCrossDeckMode = true
        self.crossDeckSourceIds = Set(decks.map { $0.deckId })
        self.flashcards = crossDeckCards.sorted { $0.stillLearningCount > $1.stillLearningCount }
    }

    func onViewAppear(delegate: PracticeDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))

        if flashcards.count == 1, !hasRecordedCompletion {
            hasRecordedCompletion = true
            interactor.trackEvent(event: Event.onPracticeSessionComplete(deckName: deckName, learnedCount: 0, stillLearningCount: 0, totalCards: 1))
            interactor.playHaptic(option: .lessonComplete())
            recordStreakEvent()
        }
    }

    func onViewDisappear(delegate: PracticeDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate, cardsViewed: selectedIndex))
    }

    // MARK: - Swipe Actions

    func onCardSwiped(isLearned: Bool) {
        guard let card = currentCard else { return }

        cardOffsets[card.flashcardId] = isLearned
        interactor.playHaptic(option: .flashcardFlip())

        if isLearned {
            interactor.trackEvent(event: Event.onCardSwipedLearned(flashcardId: card.flashcardId))
        } else {
            interactor.trackEvent(event: Event.onCardSwipedStillLearning(flashcardId: card.flashcardId))
        }

        // Persist learned status
        persistLearnedStatus(flashcardId: card.flashcardId, isLearned: isLearned)

        selectedIndex += 1

        // Check session completion
        if selectedIndex >= flashcards.count, !hasRecordedCompletion {
            hasRecordedCompletion = true
            interactor.trackEvent(event: Event.onPracticeSessionComplete(
                deckName: deckName,
                learnedCount: learnedCount,
                stillLearningCount: stillLearningCount,
                totalCards: flashcards.count
            ))
            interactor.playHaptic(option: .lessonComplete())
            recordStreakEvent()
            interactor.incrementSessionCount()
            interactor.incrementSessionsSinceLastRatingPrompt()
            interactor.incrementSessionsSinceLastPaywall()
            checkAndSetRatingPrompt()
            showSessionMilestoneUpsellIfNeeded()
        }
    }

    func onSwipeChanged(offset: CGFloat) {
        currentSwipeOffset = offset
    }

    func onUndoPressed() {
        guard canUndo else { return }

        selectedIndex -= 1

        guard let card = currentCard else { return }
        let previousIsLearned = cardOffsets[card.flashcardId]
        cardOffsets.removeValue(forKey: card.flashcardId)
        currentSwipeOffset = 0
        interactor.playHaptic(option: .light)

        interactor.trackEvent(event: Event.onUndoPressed(flashcardId: card.flashcardId))

        // Revert learned status to what it was before this session
        let originalIsLearned = card.isLearned
        if previousIsLearned != nil {
            persistLearnedStatus(flashcardId: card.flashcardId, isLearned: originalIsLearned)
        }
    }

    func onStreakCelebrationDismissed() {
        interactor.trackEvent(event: Event.onStreakCelebrationDismissed)
        showStreakCelebration = false
    }

    func onShufflePressed() {
        interactor.trackEvent(event: Event.onShufflePressed)
        interactor.playHaptic(option: .medium)

        withAnimation(.easeInOut(duration: 0.3)) {
            flashcards.shuffle()
            selectedIndex = 0
            cardOffsets = [:]
            currentSwipeOffset = 0
            hasRecordedCompletion = false
        }
    }

    func onDonePressed() {
        interactor.trackEvent(event: Event.onDonePressed)
        interactor.playHaptic(option: .light)
        router.dismissScreen()
    }

    func onPracticeAgainPressed() {
        interactor.trackEvent(event: Event.onPracticeAgainPressed)
        interactor.playHaptic(option: .medium)

        if isCrossDeckMode {
            // Reload still-learning cards from all source decks with updated counts
            let updatedCards = crossDeckSourceIds
                .compactMap { interactor.getDeck(id: $0) }
                .flatMap { $0.flashcards }
                .filter { !$0.isLearned }
                .sorted { $0.stillLearningCount > $1.stillLearningCount }
            flashcards = updatedCards
        } else if let deck = interactor.getDeck(id: deckId) {
            let cards = isReviewMode ? deck.flashcards.filter { $0.isDue } : deck.flashcards
            flashcards = cardLimit.map { Array(cards.prefix($0)) } ?? cards
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedIndex = 0
            cardOffsets = [:]
            currentSwipeOffset = 0
            hasRecordedCompletion = false
        }
    }

    // MARK: - Rating Prompt

    private func checkAndSetRatingPrompt() {
        let count = interactor.completedSessionCount

        // Early milestones — catch engaged users before they churn
        if count == 3 || count == 7 {
            interactor.setPendingRatingPrompt()
            return
        }

        // Ongoing — 60+ days since last prompt AND 5+ sessions in that period
        guard let lastDate = interactor.lastRatingPromptDate else { return }
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        guard days >= 60, interactor.sessionsSinceLastRatingPrompt >= 5 else { return }
        interactor.setPendingRatingPrompt()
    }

    // MARK: - Premium Prompt

    private func showSessionMilestoneUpsellIfNeeded() {
        guard !interactor.isPremium else { return }

        let count = interactor.completedSessionCount

        // Cap at 4 non-contextual shows total
        guard interactor.paywallNonContextualShowCount < 4 else { return }

        // First show fires exactly at session 5
        if count == 5 {
            showSessionMilestoneUpsell()
            return
        }

        // Subsequent shows: 14+ days AND 3+ sessions since the last paywall shown
        guard count > 5, let lastDate = interactor.paywallLastShownDate else { return }
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        guard days >= 14, interactor.sessionsSinceLastPaywall >= 3 else { return }

        showSessionMilestoneUpsell()
    }

    private func showSessionMilestoneUpsell() {
        interactor.trackEvent(event: Event.sessionMilestoneUpsellShown)
        router.showFirstDeckPremiumPromptModal(
            onSeeOfferPressed: { [weak self] in
                self?.router.dismissModal()
                self?.interactor.trackEvent(event: Event.sessionMilestoneUpsellAccepted)
                self?.interactor.recordPaywallShown()
                self?.router.showPaywallView(delegate: PaywallDelegate(source: "fifth_session_complete"))
            },
            onDismissPressed: { [weak self] in
                self?.router.dismissModal()
                self?.interactor.trackEvent(event: Event.sessionMilestoneUpsellDismissed)
                self?.interactor.recordPaywallShown()
            }
        )
    }

    // MARK: - Private

    private func persistLearnedStatus(flashcardId: String, isLearned: Bool) {
        // Resolve which deck contains this card
        let resolvedDeckId: String
        if isCrossDeckMode {
            guard let card = flashcards.first(where: { $0.flashcardId == flashcardId }),
                  let cardDeckId = card.deckId else { return }
            resolvedDeckId = cardDeckId
        } else {
            resolvedDeckId = deckId
        }

        guard let deck = interactor.getDeck(id: resolvedDeckId) else { return }

        let updatedFlashcards = deck.flashcards.map { card in
            if card.flashcardId == flashcardId {
                let rating: SRSRating = isLearned ? .good : .again
                let srs = SRSCalculator.calculate(card: card, rating: rating)
                let updatedStillLearningCount = isLearned ? card.stillLearningCount : card.stillLearningCount + 1
                return FlashcardModel(
                    flashcardId: card.flashcardId,
                    question: card.question,
                    answer: card.answer,
                    deckId: card.deckId,
                    isLearned: isLearned,
                    repetitions: srs.repetitions,
                    interval: srs.interval,
                    easeFactor: srs.easeFactor,
                    dueDate: srs.dueDate,
                    stillLearningCount: updatedStillLearningCount
                )
            }
            return card
        }

        let updatedDeck = DeckModel(
            deckId: deck.deckId,
            name: deck.name,
            color: deck.color,
            imageUrl: deck.imageUrl,
            sourceText: deck.sourceText,
            createdAt: deck.createdAt,
            flashcards: updatedFlashcards,
            clickCount: deck.clickCount,
            lastStudiedAt: deck.lastStudiedAt
        )

        do {
            try interactor.updateDeck(updatedDeck)
        } catch {
            interactor.trackEvent(event: Event.onPersistLearnedFail(error: error))
        }
    }

    private func recordStreakEvent() {
        let previousStreak = interactor.currentStreakData.currentStreak ?? 0

        Task { [weak self] in
            guard let self else { return }
            do {
                let metadata: [String: GamificationDictionaryValue] = [
                    "deck_name": .string(deckName),
                    "cards_count": .int(flashcards.count)
                ]
                _ = try await interactor.addStreakEvent(metadata: metadata)
                interactor.trackEvent(event: Event.onStreakEventRecorded(deckName: deckName))

                let updatedStreak = interactor.currentStreakData.currentStreak ?? 0
                if updatedStreak > previousStreak {
                    newStreakCount = updatedStreak
                }

                // Reschedule the next week of reminders with session-aware copy.
                interactor.schedulePushNotificationsForTheNextWeek(dueCount: 0, stillLearningCount: stillLearningCount)
            } catch {
                interactor.trackEvent(event: Event.onStreakEventFailed(error: error))
            }
        }
    }
}

extension PracticePresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: PracticeDelegate)
        case onDisappear(delegate: PracticeDelegate, cardsViewed: Int)
        case onCardSwipedLearned(flashcardId: String)
        case onCardSwipedStillLearning(flashcardId: String)
        case onUndoPressed(flashcardId: String)
        case onShufflePressed
        case onDonePressed
        case onPracticeAgainPressed
        case onPracticeSessionComplete(deckName: String, learnedCount: Int, stillLearningCount: Int, totalCards: Int)
        case onStreakEventRecorded(deckName: String)
        case onStreakEventFailed(error: Error)
        case onStreakCelebrationDismissed
        case onPersistLearnedFail(error: Error)
        case sessionMilestoneUpsellShown
        case sessionMilestoneUpsellAccepted
        case sessionMilestoneUpsellDismissed

        var eventName: String {
            switch self {
            case .onAppear:                     return "PracticeView_Appear"
            case .onDisappear:                  return "PracticeView_Disappear"
            case .onCardSwipedLearned:          return "PracticeView_Card_Swiped_Learned"
            case .onCardSwipedStillLearning:    return "PracticeView_Card_Swiped_StillLearning"
            case .onUndoPressed:                return "PracticeView_Undo_Pressed"
            case .onShufflePressed:             return "PracticeView_Shuffle_Pressed"
            case .onDonePressed:                return "PracticeView_Done_Pressed"
            case .onPracticeAgainPressed:       return "PracticeView_PracticeAgain_Pressed"
            case .onPracticeSessionComplete:    return "PracticeView_Session_Complete"
            case .onStreakEventRecorded:        return "PracticeView_Streak_Recorded"
            case .onStreakEventFailed:          return "PracticeView_Streak_Failed"
            case .onStreakCelebrationDismissed: return "PracticeView_Streak_Celebration_Dismissed"
            case .onPersistLearnedFail:         return "PracticeView_Persist_Learned_Fail"
            case .sessionMilestoneUpsellShown:     return "PracticeView_SessionMilestone_Upsell_Shown"
            case .sessionMilestoneUpsellAccepted:  return "PracticeView_SessionMilestone_Upsell_Accepted"
            case .sessionMilestoneUpsellDismissed: return "PracticeView_SessionMilestone_Upsell_Dismissed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate):
                return delegate.eventParameters
            case .onDisappear(delegate: let delegate, cardsViewed: let cardsViewed):
                var params = delegate.eventParameters ?? [:]
                params["cards_viewed"] = cardsViewed
                return params
            case .onCardSwipedLearned(flashcardId: let id), .onCardSwipedStillLearning(flashcardId: let id):
                return ["flashcard_id": id]
            case .onUndoPressed(flashcardId: let id):
                return ["flashcard_id": id]
            case .onPracticeSessionComplete(deckName: let name, learnedCount: let learned, stillLearningCount: let stillLearning, totalCards: let total):
                return ["deck_name": name, "learned_count": learned, "still_learning_count": stillLearning, "total_cards": total]
            case .onStreakEventRecorded(deckName: let deckName):
                return ["deck_name": deckName]
            case .onStreakEventFailed(error: let error), .onPersistLearnedFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onStreakEventFailed, .onPersistLearnedFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
