//
//  DeckDetailView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import SwiftfulUI
import PhotosUI

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

    // Edit card state
    @State private var editQuestion: String = ""
    @State private var editAnswer: String = ""

    // Edit deck state
    @State private var selectedPhotoItem: PhotosPickerItem?

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
        .sheet(item: $presenter.editingFlashcard) { flashcard in
            editCardSheet(flashcard: flashcard)
        }
        .sheet(isPresented: $presenter.showEditDeckSheet) {
            editDeckSheet
        }
        .sheet(isPresented: $showGenerateSheet, content: {
            GenerateCardsSheet(presenter: presenter)
        })
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
                        Text(presenter.practiceSubtitle)
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
                    .accessibilityLabel("Add flashcard manually")
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
                .accessibilityLabel("Generate flashcards with AI")
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(flashcard.question)
                    .font(.headline)
                Text(flashcard.answer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if flashcard.isLearned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.body)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .anyButton(.press) {
            presenter.onEditCardPressed(flashcard: flashcard)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question: \(flashcard.question), Answer: \(flashcard.answer)\(flashcard.isLearned ? ", learned" : "")")
        .accessibilityHint("Tap to edit this card")
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

            Divider()

            Button {
                presenter.onEditDeckPressed()
            } label: {
                Label("Edit Deck", systemImage: "pencil")
            }

            if presenter.learnedCount > 0 {
                Button(role: .destructive) {
                    presenter.onResetLearnedStatus()
                } label: {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .accessibilityLabel("Deck options")
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

    // MARK: - Edit Card Sheet

    private func editCardSheet(flashcard: FlashcardModel) -> some View {
        NavigationStack {
            Form {
                Section("Question") {
                    TextField("Enter question", text: $editQuestion, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Answer") {
                    TextField("Enter answer", text: $editAnswer, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presenter.onCancelEditCard()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        presenter.onSaveEditedCard(flashcardId: flashcard.flashcardId, question: editQuestion, answer: editAnswer)
                    }
                    .disabled(editQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                editQuestion = flashcard.question
                editAnswer = flashcard.answer
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Edit Deck Sheet

    private var editDeckSheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Deck name", text: $presenter.editDeckName)
                }

                Section("Color") {
                    editDeckColorPicker
                }

                Section("Cover Image") {
                    editDeckCoverImagePicker
                }
            }
            .navigationTitle("Edit Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedPhotoItem = nil
                        presenter.onCancelEditDeck()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        selectedPhotoItem = nil
                        presenter.onSaveEditedDeck()
                    }
                    .disabled(presenter.editDeckName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var editDeckColorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(DeckColor.allCases, id: \.self) { deckColor in
                    editDeckColorOption(deckColor)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func editDeckColorOption(_ deckColor: DeckColor) -> some View {
        let isSelected = presenter.editDeckColor == deckColor
        return Circle()
            .fill(deckColor.color)
            .frame(width: 36, height: 36)
            .overlay {
                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2.5)
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(isSelected ? 1.15 : 1.0)
            .shadow(color: deckColor.color.opacity(isSelected ? 0.6 : 0.3), radius: isSelected ? 4 : 2, y: 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .accessibilityLabel(isSelected ? "\(deckColor.displayName), selected" : deckColor.displayName)
            .anyButton(.press) {
                presenter.onEditDeckColorSelected(deckColor)
            }
    }

    private var editDeckCoverImagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = presenter.editDeckImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .padding(8)
                        .accessibilityLabel("Remove cover image")
                        .anyButton(.press) {
                            selectedPhotoItem = nil
                            presenter.onEditDeckRemoveImage()
                        }
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Add Cover Image")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                    }
                }
                .accessibilityLabel("Select cover image from photos")
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    presenter.onEditDeckImageDataLoaded(data)
                }
            }
        }
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
