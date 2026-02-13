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
            } else {
                cardContentView
            }
        }
        .navigationTitle(presenter.deckName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                shuffleButton
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
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Cards",
            systemImage: "rectangle.on.rectangle.slash",
            description: Text("This deck doesn't have any flashcards yet.")
        )
    }
    
    // MARK: - Card Content
    
    private var cardContentView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            FlashcardView(
                question: presenter.currentCard?.question ?? "",
                answer: presenter.currentCard?.answer ?? "",
                accentColor: presenter.deckColor.color
            )
            
            progressIndicator
            
            Spacer()
            
            navigationButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            Text("Card \(presenter.currentIndex + 1) of \(presenter.flashcards.count)")
                .font(.headline)
                .foregroundStyle(.secondary)

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
            .accessibilityLabel("Progress: card \(presenter.currentIndex + 1) of \(presenter.flashcards.count)")
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack {
            Button {
                presenter.onPreviousPressed()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(presenter.canGoPrevious ? .white : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(presenter.canGoPrevious ? presenter.deckColor.color : Color.secondary.opacity(0.2))
                )
            }
            .buttonStyle(.plain)
            .disabled(!presenter.canGoPrevious)
            .accessibilityHint(presenter.canGoPrevious ? "Go to previous card" : "Already on first card")

            Button {
                presenter.onNextPressed()
            } label: {
                HStack(spacing: 6) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(presenter.canGoNext ? .white : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(presenter.canGoNext ? presenter.deckColor.color : Color.secondary.opacity(0.2))
                )
            }
            .buttonStyle(.plain)
            .disabled(!presenter.canGoNext)
            .accessibilityHint(presenter.canGoNext ? "Go to next card" : "Already on last card")
        }
    }
    
    // MARK: - Toolbar
    
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
