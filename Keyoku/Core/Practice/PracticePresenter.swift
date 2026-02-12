//
//  PracticePresenter.swift
//  Keyoku
//
//  Created by Mark Martin on 2/10/26.
//

import SwiftUI

@Observable
@MainActor
class PracticePresenter {

    private let interactor: PracticeInteractor
    private let router: PracticeRouter

    let deckName: String
    let deckColor: DeckColor
    private(set) var flashcards: [FlashcardModel]
    private(set) var currentIndex: Int = 0
    private var hasRecordedCompletion: Bool = false

    var currentCard: FlashcardModel? {
        guard !flashcards.isEmpty, currentIndex < flashcards.count else { return nil }
        return flashcards[currentIndex]
    }

    var progress: Double {
        guard !flashcards.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(flashcards.count)
    }

    var canGoPrevious: Bool {
        currentIndex > 0
    }

    var canGoNext: Bool {
        currentIndex < flashcards.count - 1
    }

    init(interactor: PracticeInteractor, router: PracticeRouter, deck: DeckModel) {
        self.interactor = interactor
        self.router = router
        self.deckName = deck.name
        self.deckColor = deck.color
        self.flashcards = deck.flashcards
    }

    func onViewAppear(delegate: PracticeDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: PracticeDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate, cardsViewed: currentIndex + 1))
    }

    func onPreviousPressed() {
        guard canGoPrevious else { return }
        interactor.trackEvent(event: Event.onPreviousPressed(fromIndex: currentIndex))

        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex -= 1
        }
    }

    func onNextPressed() {
        guard canGoNext else { return }
        interactor.trackEvent(event: Event.onNextPressed(fromIndex: currentIndex))

        withAnimation(.easeInOut(duration: 0.2)) {
            currentIndex += 1
        }

        // Record completion when reaching the last card
        if currentIndex == flashcards.count - 1, !hasRecordedCompletion {
            hasRecordedCompletion = true
            interactor.trackEvent(event: Event.onPracticeSessionComplete(deckName: deckName, cardsCount: flashcards.count))
        }
    }

    func onShufflePressed() {
        interactor.trackEvent(event: Event.onShufflePressed)

        withAnimation(.easeInOut(duration: 0.3)) {
            flashcards.shuffle()
            currentIndex = 0
        }
    }
}

extension PracticePresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: PracticeDelegate)
        case onDisappear(delegate: PracticeDelegate, cardsViewed: Int)
        case onPreviousPressed(fromIndex: Int)
        case onNextPressed(fromIndex: Int)
        case onShufflePressed
        case onPracticeSessionComplete(deckName: String, cardsCount: Int)

        var eventName: String {
            switch self {
            case .onAppear:                     return "PracticeView_Appear"
            case .onDisappear:                  return "PracticeView_Disappear"
            case .onPreviousPressed:            return "PracticeView_Previous_Pressed"
            case .onNextPressed:                return "PracticeView_Next_Pressed"
            case .onShufflePressed:             return "PracticeView_Shuffle_Pressed"
            case .onPracticeSessionComplete:    return "PracticeView_Session_Complete"
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
            case .onPreviousPressed(fromIndex: let index), .onNextPressed(fromIndex: let index):
                return ["from_index": index]
            case .onPracticeSessionComplete(deckName: let deckName, cardsCount: let cardsCount):
                return ["deck_name": deckName, "cards_count": cardsCount]
            default:
                return nil
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
