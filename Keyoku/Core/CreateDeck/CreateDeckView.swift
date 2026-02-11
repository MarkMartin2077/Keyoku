//
//  CreateDeckView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/9/26.
//

import SwiftUI
import SwiftfulUI

struct CreateDeckDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct CreateDeckView: View {
    
    @State var presenter: CreateDeckPresenter
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
    
    // MARK: - Source Text Section
    
    private var sourceTextSection: some View {
        Section {
            TextEditor(text: $presenter.sourceText)
                .frame(minHeight: 150)
        } header: {
            Text("Source Text")
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
