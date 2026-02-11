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
    
    private let characterLimit: Int = 9500

    var body: some View {
        Form {
            deckInfoSection
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
            
            HStack {
                Spacer()
                Text("\(presenter.sourceText.count) / \(characterLimit)")
                    .font(.caption)
                    .foregroundStyle(presenter.sourceText.count > characterLimit - 500 ? .red : .secondary)
            }
        } header: {
            Text("Source Text")
        } footer: {
            Text("Paste text to generate flashcards from. Keep under \(characterLimit) characters for best results.")
        }
    }
    
    // MARK: - Generate Section
    
    private var generateSection: some View {
        Section {
            generateButton
        } footer: {
            Text("Apple Intelligence will analyze your text and create 10 flashcards.")
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
                    Text("Generating...")
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
