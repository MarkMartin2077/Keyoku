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
    private(set) var flashcards: [FlashcardModel]
    private var hasRecordedCompletion: Bool = false

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

    init(interactor: PracticeInteractor, router: PracticeRouter, deck: DeckModel) {
        self.interactor = interactor
        self.router = router
        self.deckId = deck.deckId
        self.deckName = deck.name
        self.deckColor = deck.color
        self.flashcards = deck.flashcards
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

            if learnedCount == flashcards.count, !interactor.isPremium {
                showDeckCompletedPremiumPrompt()
            }
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

    func onPracticeAgainPressed() {
        interactor.trackEvent(event: Event.onPracticeAgainPressed)
        interactor.playHaptic(option: .medium)

        // Refresh flashcards from interactor to get latest state
        if let deck = interactor.getDeck(id: deckId) {
            flashcards = deck.flashcards
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedIndex = 0
            cardOffsets = [:]
            currentSwipeOffset = 0
            hasRecordedCompletion = false
        }
    }

    // MARK: - Premium Prompt

    private func showDeckCompletedPremiumPrompt() {
        router.showDeckCompletedPremiumPromptModal(
            onSeeOfferPressed: { [weak self] in
                self?.router.dismissModal()
                self?.interactor.trackEvent(event: Event.deckCompletedPaywallAccepted)
                self?.router.showPaywallView(delegate: PaywallDelegate(source: "deck_completed"))
            },
            onDismissPressed: { [weak self] in
                self?.router.dismissModal()
                self?.interactor.trackEvent(event: Event.deckCompletedPaywallDismissed)
            }
        )
    }

    // MARK: - Private

    private func persistLearnedStatus(flashcardId: String, isLearned: Bool) {
        guard let deck = interactor.getDeck(id: deckId) else { return }

        let updatedFlashcards = deck.flashcards.map { card in
            if card.flashcardId == flashcardId {
                return FlashcardModel(
                    flashcardId: card.flashcardId,
                    question: card.question,
                    answer: card.answer,
                    deckId: card.deckId,
                    isLearned: isLearned
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
            clickCount: deck.clickCount
        )

        do {
            try interactor.updateDeck(updatedDeck)
        } catch {
            interactor.trackEvent(event: Event.onPersistLearnedFail(error: error))
        }
    }

    private func recordStreakEvent() {
        let previousStreak = interactor.currentStreakData.currentStreak ?? 0

        Task {
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
                    showStreakCelebration = true

                    if updatedStreak == 3 || updatedStreak == 7 {
                        AppStoreRatingsHelper.requestReviewIfNeeded()
                    }
                }
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
        case onPracticeAgainPressed
        case onPracticeSessionComplete(deckName: String, learnedCount: Int, stillLearningCount: Int, totalCards: Int)
        case onStreakEventRecorded(deckName: String)
        case onStreakEventFailed(error: Error)
        case onStreakCelebrationDismissed
        case onPersistLearnedFail(error: Error)
        case deckCompletedPaywallAccepted
        case deckCompletedPaywallDismissed

        var eventName: String {
            switch self {
            case .onAppear:                     return "PracticeView_Appear"
            case .onDisappear:                  return "PracticeView_Disappear"
            case .onCardSwipedLearned:          return "PracticeView_Card_Swiped_Learned"
            case .onCardSwipedStillLearning:    return "PracticeView_Card_Swiped_StillLearning"
            case .onUndoPressed:                return "PracticeView_Undo_Pressed"
            case .onShufflePressed:             return "PracticeView_Shuffle_Pressed"
            case .onPracticeAgainPressed:       return "PracticeView_PracticeAgain_Pressed"
            case .onPracticeSessionComplete:    return "PracticeView_Session_Complete"
            case .onStreakEventRecorded:        return "PracticeView_Streak_Recorded"
            case .onStreakEventFailed:          return "PracticeView_Streak_Failed"
            case .onStreakCelebrationDismissed: return "PracticeView_Streak_Celebration_Dismissed"
            case .onPersistLearnedFail:         return "PracticeView_Persist_Learned_Fail"
            case .deckCompletedPaywallAccepted:  return "PracticeView_DeckCompleted_Paywall_Accepted"
            case .deckCompletedPaywallDismissed: return "PracticeView_DeckCompleted_Paywall_Dismissed"
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
