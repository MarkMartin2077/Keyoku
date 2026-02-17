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
    @State private var showGenerateSheet: Bool = false
    @State private var newQuestion: String = ""
    @State private var newAnswer: String = ""

    var body: some View {
        List {
            if let imageUrl = presenter.deckImageUrlString {
                coverImageHeader(urlString: imageUrl)
            }

            if !presenter.flashcards.isEmpty {
                practiceSection
            }

            if presenter.flashcards.isEmpty {
                emptyStateView
            } else {
                flashcardsSection
            }
        }
        .navigationTitle(presenter.deckName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addMenu
            }
        }
        .sheet(isPresented: $showAddCardSheet) {
            addCardSheet
        }
        .sheet(isPresented: $showGenerateSheet, onDismiss: {}) {
            GenerateCardsSheet(presenter: presenter)
        }
        .onChange(of: showGenerateSheet) { _, isPresented in
            if isPresented {
                presenter.onGenerateSheetOpened()
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Cover Image Header

    private func coverImageHeader(urlString: String) -> some View {
        ImageLoaderView(urlString: urlString)
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
    }

    // MARK: - Practice Section

    private var practiceSection: some View {
        Section {
            Button {
                presenter.onPracticePressed()
            } label: {
                HStack {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.title2)
                        .foregroundStyle(presenter.deckColor.color)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Practice")
                            .font(.headline)
                        Text("Study all \(presenter.flashcards.count) cards")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Start studying all cards in this deck")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No Cards Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add flashcards manually or generate them with AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Text("Add Card")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    )
                    .anyButton(.press) {
                        showAddCardSheet = true
                    }

                HStack(spacing: 6) {
                    Image(systemName: "apple.intelligence")
                        .font(.caption)
                    Text("Generate")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor)
                )
                .anyButton(.press) {
                    showGenerateSheet = true
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Flashcards Section

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question: \(flashcard.question), Answer: \(flashcard.answer)")
    }

    // MARK: - Add Menu

    private var addMenu: some View {
        Menu {
            Button {
                showAddCardSheet = true
            } label: {
                Label("Add Card", systemImage: "plus")
            }

            Button {
                showGenerateSheet = true
            } label: {
                Label("Generate with AI", systemImage: "apple.intelligence")
            }
        } label: {
            Image(systemName: "plus")
                .accessibilityLabel("Add flashcards")
        }
    }

    // MARK: - Add Card Sheet

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

    return NavigationStack {
        RouterView { router in
            builder.deckDetailView(router: router, delegate: delegate)
        }
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
