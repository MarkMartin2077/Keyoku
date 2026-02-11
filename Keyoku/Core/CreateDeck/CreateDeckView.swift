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
            cardAmountSection
            sourceTextSection
            generateSection
        }
        .navigationTitle("Create Deck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    presenter.onCancelPressed()
                }
                .disabled(presenter.isGenerating)
            }
        }
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
    
    // MARK: - Generate Section
    
    private var generateSection: some View {
        Section {
            generateButton
        } footer: {
            Text("Apple Intelligence will analyze your text and create \(presenter.cardCount) flashcards.")
        }
    }
    
    @ViewBuilder
    private var generateButton: some View {
        Button {
            presenter.onGeneratePressed()
        } label: {
            HStack {
                Spacer()
                
                if presenter.isGenerating {
                    ProgressView()
                        .tint(.white)
                    Text("Generating batch \(presenter.generationProgress) of \(presenter.generationTotal)…")
                } else {
                    Image(systemName: "apple.intelligence")
                    Text("Generate")
                }
                
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
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
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
