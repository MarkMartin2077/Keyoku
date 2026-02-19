//
//  PracticeView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/10/26.
//

import SwiftUI
import SwiftfulUI

struct PracticeDelegate {
    let deck: DeckModel

    var eventParameters: [String: Any]? {
        deck.eventParameters
    }
}

struct PracticeView: View {

    @State var presenter: PracticePresenter
    let delegate: PracticeDelegate

    var body: some View {
        VStack(spacing: 0) {
            if presenter.flashcards.isEmpty {
                emptyStateView
            } else if presenter.isSessionComplete {
                sessionCompleteView
            } else {
                cardContentView
            }
        }
        .navigationTitle(presenter.deckName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !presenter.isSessionComplete {
                        undoButton
                    }
                    shuffleButton
                }
            }
        }
        .overlay {
            if presenter.showStreakCelebration {
                StreakCelebrationView(
                    streakCount: presenter.newStreakCount,
                    onDismiss: {
                        presenter.onStreakCelebrationDismissed()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: presenter.showStreakCelebration)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Cards",
            systemImage: "rectangle.on.rectangle.slash",
            description: Text("This deck doesn't have any flashcards yet.")
        )
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
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            presenter.onSwipeChanged(offset: value.translation.width)
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 100
                            if value.translation.width > threshold {
                                // Swipe right — learned
                                withAnimation(.easeOut(duration: 0.3)) {
                                    presenter.onSwipeChanged(offset: 500)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    presenter.onCardSwiped(isLearned: true)
                                    presenter.onSwipeChanged(offset: 0)
                                }
                            } else if value.translation.width < -threshold {
                                // Swipe left — still learning
                                withAnimation(.easeOut(duration: 0.3)) {
                                    presenter.onSwipeChanged(offset: -500)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    presenter.onCardSwiped(isLearned: false)
                                    presenter.onSwipeChanged(offset: 0)
                                }
                            } else {
                                // Snap back
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    presenter.onSwipeChanged(offset: 0)
                                }
                            }
                        }
                )
                .overlay(alignment: .leading) {
                    swipeIndicator(
                        systemName: "arrow.trianglehead.2.clockwise.rotate.90",
                        color: .orange,
                        isVisible: presenter.currentSwipeOffset < -50
                    )
                    .padding(.leading, 24)
                }
                .overlay(alignment: .trailing) {
                    swipeIndicator(
                        systemName: "checkmark",
                        color: .green,
                        isVisible: presenter.currentSwipeOffset > 50
                    )
                    .padding(.trailing, 24)
                }
            }
        }
    }

    private func swipeIndicator(systemName: String, color: Color, isVisible: Bool) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(color)
            .padding(16)
            .background {
                Circle()
                    .fill(color.opacity(0.15))
            }
            .scaleEffect(isVisible ? 1.0 : 0.5)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isVisible)
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

    // MARK: - Session Complete

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(presenter.learnedCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("Learned")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Rectangle()
                    .fill(.secondary.opacity(0.3))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("\(presenter.stillLearningCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("Still Learning")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("Practice Again")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(presenter.deckColor.color)
                )
                .padding(.horizontal, 24)
                .anyButton(.press) {
                    presenter.onPracticeAgainPressed()
                }

            Spacer()
                .frame(height: 24)
        }
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

    func practiceView(router: AnyRouter, delegate: PracticeDelegate) -> some View {
        PracticeView(
            presenter: PracticePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                deck: delegate.deck
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showPracticeView(deck: DeckModel) {
        let delegate = PracticeDelegate(deck: deck)
        router.showScreen(.push) { router in
            builder.practiceView(router: router, delegate: delegate)
        }
    }

}
