//
//  DeckDetailView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import SwiftfulUI

struct DeckDetailDelegate {
    let deck: DeckModel
    
    var eventParameters: [String: Any]? {
        deck.eventParameters
    }
}

struct DeckDetailView: View {
    
    @State var presenter: DeckDetailPresenter
    let delegate: DeckDetailDelegate
    
    @State private var showAddCardSheet: Bool = false
    @State private var newQuestion: String = ""
    @State private var newAnswer: String = ""

    var body: some View {
        List {
            if presenter.flashcards.isEmpty {
                emptyStateView
            } else {
                flashcardsSection
            }
        }
        .navigationTitle(presenter.deckName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addButton
            }
        }
        .sheet(isPresented: $showAddCardSheet) {
            addCardSheet
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Cards Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add flashcards to start studying")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Add Card") {
                showAddCardSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
    }
    
    private var flashcardsSection: some View {
        Section {
            ForEach(presenter.flashcards) { flashcard in
                flashcardRow(flashcard: flashcard)
            }
            .onDelete { indexSet in
                presenter.onDeleteFlashcards(at: indexSet)
            }
        } header: {
            Text("\(presenter.flashcards.count) Card\(presenter.flashcards.count == 1 ? "" : "s")")
        }
    }
    
    private func flashcardRow(flashcard: FlashcardModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(flashcard.question)
                .font(.headline)
            Text(flashcard.answer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var addButton: some View {
        Image(systemName: "plus")
            .anyButton(.press) {
                showAddCardSheet = true
            }
    }
    
    private var addCardSheet: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("Enter question", text: $newQuestion, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Answer") {
                    TextField("Enter answer", text: $newAnswer, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetAndCloseSheet()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        presenter.onAddCardPressed(question: newQuestion, answer: newAnswer)
                        resetAndCloseSheet()
                    }
                    .disabled(newQuestion.isEmpty || newAnswer.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func resetAndCloseSheet() {
        newQuestion = ""
        newAnswer = ""
        showAddCardSheet = false
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = DeckDetailDelegate(deck: .mock)
    
    return RouterView { router in
        builder.deckDetailView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {
    
    func deckDetailView(router: AnyRouter, delegate: DeckDetailDelegate) -> some View {
        DeckDetailView(
            presenter: DeckDetailPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self),
                deck: delegate.deck
            ),
            delegate: delegate
        )
    }
    
}

extension CoreRouter {
    
    func showDeckDetailView(delegate: DeckDetailDelegate) {
        router.showScreen(.push) { router in
            builder.deckDetailView(router: router, delegate: delegate)
        }
    }
    
}
