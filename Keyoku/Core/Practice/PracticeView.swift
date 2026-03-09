//
//  PracticeView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/10/26.
//

import SwiftUI
import SwiftfulUI

struct PracticeDelegate {
    let deck: DeckModel?
    let crossDeckCards: [FlashcardModel]?
    let crossDeckSource: [DeckModel]?

    init(deck: DeckModel) {
        self.deck = deck
        self.crossDeckCards = nil
        self.crossDeckSource = nil
    }

    init(crossDeckCards: [FlashcardModel], crossDeckSource: [DeckModel]) {
        self.deck = nil
        self.crossDeckCards = crossDeckCards
        self.crossDeckSource = crossDeckSource
    }

    var eventParameters: [String: Any]? {
        deck?.eventParameters
    }
}

struct PracticeView: View {

    @State var presenter: PracticePresenter
    let delegate: PracticeDelegate

    @State private var isSwipeAnimating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if presenter.flashcards.isEmpty {
                emptyStateView
            } else if presenter.isSessionComplete {
                SessionCompleteView(
                    learnedCount: presenter.learnedCount,
                    stillLearningCount: presenter.stillLearningCount,
                    newStreakCount: presenter.newStreakCount,
                    nextReviewLabel: presenter.nextReviewLabel,
                    deckColor: presenter.deckColor.color,
                    onPracticeAgainPressed: { presenter.onPracticeAgainPressed() },
                    onDonePressed: { presenter.onDonePressed() }
                )
            } else {
                cardContentView
            }
        }
        .navigationTitle(presenter.deckName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !presenter.isSessionComplete {
                    Button {
                        presenter.onDonePressed()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("End session")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !presenter.isSessionComplete {
                        undoButton
                    }
                    shuffleButton
                }
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        if presenter.isReviewMode {
            ContentUnavailableView(
                "No Cards Due",
                systemImage: "checkmark.circle",
                description: Text("All cards are up to date. Check back later for your next review.")
            )
        } else {
            ContentUnavailableView(
                "No Cards",
                systemImage: "rectangle.on.rectangle.slash",
                description: Text("This deck doesn't have any flashcards yet.")
            )
        }
    }

    // MARK: - Card Content

    private var cardContentView: some View {
        VStack(spacing: 16) {
            progressHeader
                .padding(.top, 8)

            Spacer()

            cardStack
                .padding(.horizontal, 8)

            Spacer()

            swipeHint
                .padding(.bottom, 24)
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(presenter.learnedCount)")
                        .fontWeight(.semibold)
                    Text("Learned")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
                        .foregroundStyle(.orange)
                    Text("\(presenter.stillLearningCount)")
                        .fontWeight(.semibold)
                    Text("Still Learning")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(presenter.deckColor.color)
                        .frame(width: geometry.size.width * presenter.progress)
                        .animation(.easeInOut(duration: 0.3), value: presenter.progress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 40)

            Text("Card \(presenter.selectedIndex + 1) of \(presenter.flashcards.count)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            // Show next card behind (if exists)
            if presenter.selectedIndex + 1 < presenter.flashcards.count {
                let nextCard = presenter.flashcards[presenter.selectedIndex + 1]
                FlashcardView(
                    question: nextCard.question,
                    answer: nextCard.answer,
                    accentColor: presenter.deckColor.color
                )
                .scaleEffect(0.95)
                .opacity(0.5)
                .allowsHitTesting(false)
            }

            // Current card with drag gesture
            if let card = presenter.currentCard {
                FlashcardView(
                    question: card.question,
                    answer: card.answer,
                    accentColor: presenter.deckColor.color
                )
                .offset(x: presenter.currentSwipeOffset)
                .rotationEffect(.degrees(Double(presenter.currentSwipeOffset) / 20))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            guard !isSwipeAnimating else { return }
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                // Vertical-dominant — yield to ScrollView
                                presenter.onSwipeChanged(offset: 0)
                                return
                            }
                            presenter.onSwipeChanged(offset: value.translation.width)
                        }
                        .onEnded { value in
                            guard !isSwipeAnimating else { return }
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                // Vertical-dominant — snap back
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    presenter.onSwipeChanged(offset: 0)
                                }
                                return
                            }
                            let threshold: CGFloat = 100
                            if value.translation.width > threshold {
                                // Swipe right — learned
                                isSwipeAnimating = true
                                withAnimation(.easeOut(duration: 0.3)) {
                                    presenter.onSwipeChanged(offset: 500)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    presenter.onCardSwiped(isLearned: true)
                                    presenter.onSwipeChanged(offset: 0)
                                    isSwipeAnimating = false
                                }
                            } else if value.translation.width < -threshold {
                                // Swipe left — still learning
                                isSwipeAnimating = true
                                withAnimation(.easeOut(duration: 0.3)) {
                                    presenter.onSwipeChanged(offset: -500)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    presenter.onCardSwiped(isLearned: false)
                                    presenter.onSwipeChanged(offset: 0)
                                    isSwipeAnimating = false
                                }
                            } else {
                                // Snap back
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    presenter.onSwipeChanged(offset: 0)
                                }
                            }
                        }
                )
                .overlay(alignment: .topLeading) {
                    swipeStamp(
                        systemName: "checkmark",
                        color: .green,
                        rotation: -12,
                        dragOffset: max(0, presenter.currentSwipeOffset)
                    )
                    .padding([.leading, .top], 20)
                }
                .overlay(alignment: .topTrailing) {
                    swipeStamp(
                        systemName: "arrow.trianglehead.2.clockwise.rotate.90",
                        color: .orange,
                        rotation: 12,
                        dragOffset: abs(min(0, presenter.currentSwipeOffset))
                    )
                    .padding([.trailing, .top], 20)
                }
            }
        }
    }

    private func swipeStamp(systemName: String, color: Color, rotation: Double, dragOffset: CGFloat) -> some View {
        let progress = min(1.0, dragOffset / 55.0)

        return Image(systemName: systemName)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(color)
            .padding(16)
            .background {
                Circle()
                    .fill(color.opacity(0.15))
            }
            .rotationEffect(.degrees(rotation))
            .opacity(progress)
            .scaleEffect(0.5 + 0.5 * progress)
    }

    // MARK: - Swipe Hint

    private var swipeHint: some View {
        HStack(spacing: 24) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left")
                Text("Still Learning")
            }
            .foregroundStyle(.orange)

            HStack(spacing: 4) {
                Text("Learned")
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(.green)
        }
        .font(.caption)
        .fontWeight(.medium)
    }

    // MARK: - Toolbar

    private var undoButton: some View {
        Button {
            presenter.onUndoPressed()
        } label: {
            Image(systemName: "arrow.uturn.backward")
        }
        .disabled(!presenter.canUndo)
        .accessibilityLabel("Undo last swipe")
    }

    private var shuffleButton: some View {
        Button {
            presenter.onShufflePressed()
        } label: {
            Image(systemName: "shuffle")
        }
        .disabled(presenter.flashcards.count < 2)
        .accessibilityLabel("Shuffle cards")
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = PracticeDelegate(deck: .mock)

    return NavigationStack {
        RouterView { router in
            builder.practiceView(router: router, delegate: delegate)
        }
    }
}

extension CoreBuilder {

    func practiceView(router: AnyRouter, delegate: PracticeDelegate, dueOnly: Bool = false, cardLimit: Int? = nil) -> some View {
        let coreRouter = CoreRouter(router: router, builder: self)
        let presenter: PracticePresenter
        if let deck = delegate.deck {
            presenter = PracticePresenter(
                interactor: interactor,
                router: coreRouter,
                deck: deck,
                dueOnly: dueOnly,
                cardLimit: cardLimit
            )
        } else if let cards = delegate.crossDeckCards, let decks = delegate.crossDeckSource {
            presenter = PracticePresenter(
                interactor: interactor,
                router: coreRouter,
                crossDeckCards: cards,
                decks: decks
            )
        } else {
            // Fallback: empty presenter with no cards
            presenter = PracticePresenter(
                interactor: interactor,
                router: coreRouter,
                crossDeckCards: [],
                decks: []
            )
        }
        return PracticeView(presenter: presenter, delegate: delegate)
    }

    func crossDeckPracticeView(router: AnyRouter, delegate: PracticeDelegate) -> some View {
        practiceView(router: router, delegate: delegate)
    }

}

extension CoreRouter {

    func showPracticeView(deck: DeckModel, cardLimit: Int? = nil) {
        let delegate = PracticeDelegate(deck: deck)
        router.showScreen(.fullScreenCover) { router in
            builder.practiceView(router: router, delegate: delegate, cardLimit: cardLimit)
        }
    }

    func showReviewDueView(deck: DeckModel) {
        let delegate = PracticeDelegate(deck: deck)
        router.showScreen(.fullScreenCover) { router in
            builder.practiceView(router: router, delegate: delegate, dueOnly: true)
        }
    }

}
