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

    var body: some View {
        Form {
            deckInfoSection
            creationModePicker

            if presenter.creationMode == .generate {
                cardAmountSection
                sourceTextSection
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
                generatingOverlay
            }
        }
        .navigationTitle("Create Deck")
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
        .interactiveDismissDisabled(presenter.isGenerating)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }
    
    // MARK: - Deck Info Section
    
    private var deckInfoSection: some View {
        Section {
            TextField("Deck Name", text: $presenter.deckName)

            colorPicker

        } header: {
            Text("Deck Info")
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
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Card Amount Section
    
    private var cardAmountSection: some View {
        Section {
            Stepper("\(presenter.cardCount) cards", value: $presenter.cardCount, in: 10...50, step: 5)
        } header: {
            Text("Number of Cards")
        } footer: {
            Text("More cards require more source text for best results.")
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
        Circle()
            .fill(deckColor.color)
            .frame(width: 32, height: 32)
            .overlay {
                if presenter.selectedColor == deckColor {
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: deckColor.color.opacity(0.4), radius: 2, y: 1)
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

                    Button {
                        selectedPhotoItem = nil
                        presenter.onRemoveImage()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding(8)
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
                    Text(mode.rawValue).tag(mode)
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
            generateButton
        case .empty:
            createEmptyButton
        }
    }
    
    @ViewBuilder
    private var generateButton: some View {
        Button {
            presenter.onGeneratePressed()
        } label: {
            HStack {
                Spacer()
                
                Image(systemName: "apple.intelligence")
                Text("Generate")
                
                Spacer()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(presenter.canGenerate ? Color.accentColor : Color.gray)
            )
        }
        .buttonStyle(.plain)
        .disabled(!presenter.canGenerate)
    }
    
    @ViewBuilder
    private var createEmptyButton: some View {
        Button {
            presenter.onCreateEmptyPressed()
        } label: {
            HStack {
                Spacer()
                
                Image(systemName: "rectangle.stack.badge.plus")
                Text("Create Deck")
                
                Spacer()
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(presenter.canCreateEmpty ? Color.accentColor : Color.gray)
            )
        }
        .buttonStyle(.plain)
        .disabled(!presenter.canCreateEmpty)
    }
    
    // MARK: - Generating Overlay
    
    private var generatingOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "apple.intelligence")
                    .font(.system(size: 48))
                    .foregroundStyle(.accent)
                    .symbolEffect(.pulse, isActive: true)
                
                VStack(spacing: 8) {
                    Text("Generating Flashcards")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Creating \(presenter.cardCount) cards for **\(presenter.deckName)**")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if presenter.generationTotal > 0 {
                    VStack(spacing: 12) {
                        ProgressView(
                            value: Double(presenter.generationProgress),
                            total: Double(presenter.generationTotal)
                        )
                        .tint(.accent)
                        .frame(maxWidth: 220)
                        
                        Text("Batch \(presenter.generationProgress) of \(presenter.generationTotal)")
                            .font(.caption)
                            .contentTransition(.numericText())
                            .animation(.smooth, value: presenter.generationProgress)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
                
                Spacer()
                
                Text("This may take a moment depending on the amount of source text.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)
            }
            .padding()
        }
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

extension CoreRouter {
    
    func showCreateDeckView(delegate: CreateDeckDelegate) {
        router.showScreen(.sheet) { router in
            NavigationStack {
                builder.createDeckView(router: router, delegate: delegate)
            }
        }
    }
    
}
