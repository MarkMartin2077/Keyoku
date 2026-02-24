//
//  CreateDeckView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import SwiftfulUI
import PhotosUI
import UniformTypeIdentifiers
import FoundationModels

struct CreateDeckDelegate {

    var eventParameters: [String: Any]? {
        nil
    }
}

struct CreateDeckView: View {
    
    @State var presenter: CreateDeckPresenter
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingPDFPicker: Bool = false
    let delegate: CreateDeckDelegate

    private var model: SystemLanguageModel { .default }

    var body: some View {
        Form {
            deckPreviewSection
            deckInfoSection
            creationModePicker

            if presenter.creationMode == .generate {
                if case .available = model.availability {
                    cardAmountSection
                    sourceTextSection
                } else if case .unavailable(let reason) = model.availability {
                    Section {
                        AppleIntelligenceUnavailableView(
                            reason: reason,
                            onOpenSettings: nil
                        )
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !presenter.isGenerating {
                bottomActionButton
                    .padding()
                    .background(.bar)
            }
        }
        .overlay {
            if presenter.isGenerating {
                CreateDeckGeneratingOverlay(presenter: presenter)
            } else if presenter.isGenerationComplete {
                CreateDeckSuccessOverlay(presenter: presenter) {
                    presenter.onSuccessDismissPressed()
                }
            } else if presenter.showFirstDeckCelebration {
                FirstDeckCelebrationView {
                    presenter.onFirstDeckCelebrationDismissed()
                }
            }
        }
        .navigationTitle("Create")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if !presenter.isGenerating {
                    Button("Cancel") {
                        presenter.onCancelPressed()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showingPDFPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    presenter.onPDFFileSelected(result: .success(url))
                }
            case .failure(let error):
                presenter.onPDFFileSelected(result: .failure(error))
            }
        }
        .interactiveDismissDisabled(presenter.isGenerating || presenter.isGenerationComplete || presenter.showFirstDeckCelebration)
        .onChange(of: presenter.sourceText) {
            presenter.clampCardCountIfNeeded()
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
    
    // MARK: - Live Preview

    private var deckPreviewSection: some View {
        Section {
            deckPreviewCard
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }

    @FocusState private var isNameFieldFocused: Bool

    private var deckPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $presenter.deckName, prompt: Text("Deck Name").foregroundStyle(.white.opacity(0.5)))
                .font(.headline)
                .foregroundStyle(.white)
                .tint(.white)
                .focused($isNameFieldFocused)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("DeckNameField")

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.caption2)
                Text(presenter.creationMode == .generate ? "\(presenter.cardCount) cards" : "Empty")
                    .font(.caption)
            }
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 130)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [presenter.selectedColor.color, presenter.selectedColor.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let image = presenter.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.35))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            isNameFieldFocused = true
        }
        .animation(.smooth(duration: 0.3), value: presenter.selectedColor)
        .animation(.smooth(duration: 0.3), value: presenter.selectedImage != nil)
    }

    // MARK: - Deck Info Section

    private var deckInfoSection: some View {
        Section {
            colorPicker

            coverImagePicker

        } header: {
            Text("Details")
        }
    }
    
    // MARK: - Creation Mode Picker
    
    private var creationModePicker: some View {
        Section {
            Picker("Creation Method", selection: Binding(
                get: { presenter.creationMode },
                set: { presenter.onCreationModeChanged($0) }
            )) {
                ForEach(CreateDeckPresenter.CreationMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Card Amount Section

    private var cardAmountSection: some View {
        Section {
            Stepper("\(presenter.cardCount) cards", value: $presenter.cardCount, in: 10...presenter.maxCardCount, step: 5)
        } header: {
            Text("Number of Cards")
        } footer: {
            if presenter.maxCardCount < 50 {
                Text("Add more source text to unlock up to 50 cards. Current max: \(presenter.maxCardCount).")
            } else {
                Text("You have enough source text for up to 50 cards.")
            }
        }
    }
    
    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DeckColor.allCases, id: \.self) { deckColor in
                        colorOption(deckColor)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func colorOption(_ deckColor: DeckColor) -> some View {
        let isSelected = presenter.selectedColor == deckColor
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
                presenter.onColorSelected(deckColor)
            }
    }
    
    // MARK: - Cover Image Picker

    private var coverImagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cover Image")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let image = presenter.selectedImage {
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
                            presenter.onRemoveImage()
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
                    presenter.onImageDataLoaded(data)
                }
            }
        }
    }

    // MARK: - Source Text Section

    private var sourceTextSection: some View {
        Section {
            Picker("Source Input", selection: Binding(
                get: { presenter.sourceInputMode },
                set: { presenter.onSourceInputModeChanged($0) }
            )) {
                ForEach(CreateDeckPresenter.SourceInputMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch presenter.sourceInputMode {
            case .text:
                TextEditor(text: $presenter.sourceText)
                    .frame(minHeight: 150)
            case .pdf:
                pdfUploadContent
            }
        } header: {
            Text("Source Text")
        } footer: {
            if presenter.sourceTextTooShort {
                let remaining = CreateDeckPresenter.minimumSourceTextLength - presenter.trimmedSourceTextLength
                Text("Add at least \(remaining) more characters. Paste notes, textbook excerpts, or study material to generate quality flashcards.")
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - PDF Upload Content

    @ViewBuilder
    private var pdfUploadContent: some View {
        if presenter.isExtractingPDF {
            HStack(spacing: 12) {
                ProgressView()
                Text("Extracting text from PDF...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
        } else if let fileName = presenter.pdfFileName {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundStyle(.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fileName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if let pageCount = presenter.pdfPageCount {
                                Text("\(pageCount) pages")
                            }
                            Text("\(presenter.sourceText.count) characters")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                }

                Button(role: .destructive) {
                    presenter.onClearPDF()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove PDF")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 8)
        } else {
            VStack(spacing: 12) {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Upload a PDF document")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                Button {
                    showingPDFPicker = true
                } label: {
                    HStack {
                        Image(systemName: "folder")
                        Text("Select PDF")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if let error = presenter.pdfError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Bottom Action Button
    
    @ViewBuilder
    private var bottomActionButton: some View {
        switch presenter.creationMode {
        case .generate:
            if case .available = model.availability {
                generateButton
            }
        case .empty:
            createEmptyButton
        }
    }
    
    @ViewBuilder
    private var generateButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.intelligence")
            Text("Generate")
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    presenter.canGenerate
                    ? AnyShapeStyle(LinearGradient(
                        colors: [.accent, .accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    : AnyShapeStyle(Color.gray)
                )
        }
        .anyButton(.press) {
            presenter.onGeneratePressed()
        }
        .accessibilityIdentifier("GenerateButton")
        .disabled(!presenter.canGenerate)
        .accessibilityHint(presenter.canGenerate ? "" : "Enter a deck name and source text to generate")
    }

    @ViewBuilder
    private var createEmptyButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack.badge.plus")
            Text("Create Empty Deck")
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    presenter.canCreateEmpty
                    ? AnyShapeStyle(LinearGradient(
                        colors: [.accent, .accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    : AnyShapeStyle(Color.gray)
                )
        }
        .accessibilityHint(presenter.canCreateEmpty ? "Creates an empty deck" : "Enter a deck name to create")
        .anyButton(.press) {
            presenter.onCreateEmptyPressed()
        }
        .accessibilityIdentifier("CreateEmptyDeckButton")
        .disabled(!presenter.canCreateEmpty)
    }
    
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = CreateDeckDelegate()
    
    return NavigationStack {
        RouterView { router in
            builder.createDeckView(router: router, delegate: delegate)
        }
    }
}

extension CoreRouter {

    func showCreateContentView(onDismiss: (() -> Void)? = nil) {
        let delegate = CreateDeckDelegate()
        router.showScreen(.sheet, onDismiss: onDismiss) { router in
            builder.createDeckView(router: router, delegate: delegate)
        }
    }

}

extension CoreBuilder {

    func createDeckView(router: AnyRouter, delegate: CreateDeckDelegate) -> some View {
        CreateDeckView(
            presenter: CreateDeckPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}
