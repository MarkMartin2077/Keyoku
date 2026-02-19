//
//  GenerateCardsSheet.swift
//  Keyoku
//
//  Created by Mark Martin on 2/17/26.
//

import SwiftUI
import SwiftfulUI
import Combine
import UniformTypeIdentifiers

struct GenerateCardsSheet: View {

    let presenter: DeckDetailPresenter
    @Environment(\.dismiss) private var dismiss
    @State private var showingPDFPicker: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                if presenter.isGeneratingCards {
                    generatingOverlay
                } else if presenter.isGenerationComplete {
                    successOverlay
                } else {
                    formContent
                }
            }
            .navigationTitle("Generate Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !presenter.isGeneratingCards && !presenter.isGenerationComplete {
                        Button("Cancel") {
                            dismiss()
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
            .interactiveDismissDisabled(presenter.isGeneratingCards || presenter.isGenerationComplete)
            .onChange(of: presenter.sourceText) {
                presenter.clampCardCountIfNeeded()
            }
        }
    }

    // MARK: - Form Content

    private var formContent: some View {
        Form {
            sourceTextSection
            cardAmountSection
        }
        .safeAreaInset(edge: .bottom) {
            generateButton
                .padding()
                .background(.bar)
        }
    }

    // MARK: - Source Text Section

    private var sourceTextSection: some View {
        Section {
            Picker("Source Input", selection: Binding(
                get: { presenter.sourceInputMode },
                set: { presenter.onSourceInputModeChanged($0) }
            )) {
                ForEach(DeckDetailPresenter.SourceInputMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch presenter.sourceInputMode {
            case .text:
                TextEditor(text: Binding(
                    get: { presenter.sourceText },
                    set: { presenter.sourceText = $0 }
                ))
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

    // MARK: - Card Amount Section

    private var cardAmountSection: some View {
        Section {
            Stepper("\(presenter.cardCount) cards", value: Binding(
                get: { presenter.cardCount },
                set: { presenter.cardCount = $0 }
            ), in: 10...presenter.maxCardCount, step: 5)
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

    // MARK: - Generate Button

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
            presenter.onGenerateCardsPressed()
        }
        .disabled(!presenter.canGenerate)
        .accessibilityHint(presenter.canGenerate ? "" : "Enter source text to generate cards")
    }

    // MARK: - Generating Overlay

    private var generatingOverlay: some View {
        GeneratingCardsOverlay(presenter: presenter)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)

                Text("Cards Added!")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "rectangle.on.rectangle")
                            .foregroundStyle(.accent)
                            .frame(width: 24)
                        Text("Cards Generated")
                            .font(.subheadline)
                        Spacer(minLength: 0)
                        Text("\(presenter.generatedFlashcardCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )

                if presenter.skippedBatches > 0 {
                    Text("\(presenter.skippedBatches) section(s) skipped due to content restrictions.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 0)

                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.accentColor)
                    )
                    .accessibilityLabel("Done")
                    .anyButton(.press) {
                        presenter.onGenerateCardsSuccessDismissed()
                        dismiss()
                    }
                    .padding(.bottom, 16)
            }
            .padding(24)
        }
    }
}

// MARK: - Generating Cards Overlay

private struct GeneratingCardsOverlay: View {

    let presenter: DeckDetailPresenter

    @State private var currentPhraseIndex: Int = 0

    private let progressPhrases: [String] = [
        "Analyzing your source material...",
        "Extracting key concepts...",
        "Crafting thoughtful questions...",
        "Building answer explanations...",
        "Identifying important details...",
        "Creating varied question types...",
        "Refining card clarity...",
        "Connecting related ideas...",
        "Polishing final wording...",
        "Ensuring comprehensive coverage...",
        "Organizing by topic...",
        "Almost there, finishing up..."
    ]

    private var streamedItems: [StreamedCardItem] {
        presenter.streamedFlashcards.map { card in
            StreamedCardItem(id: card.flashcardId, content: card.question)
        }
    }

    private var totalGenerated: Int {
        presenter.flashcardItemsGenerated
    }

    private var totalTarget: Int {
        presenter.cardCount
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 40)

                Spacer(minLength: 0)

                cardStackSection
                    .padding(.horizontal, 32)

                Spacer(minLength: 0)

                footerSection
                    .padding(.bottom, 32)
            }
            .padding()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 40))
                .foregroundStyle(.accent)
                .symbolEffect(.pulse, isActive: true)

            Text("Generating Flashcards")
                .font(.title3)
                .fontWeight(.bold)

            Text("\(totalGenerated) of \(totalTarget)")
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.smooth, value: totalGenerated)
        }
    }

    // MARK: - Card Stack

    private var cardStackSection: some View {
        let visibleItems = Array(streamedItems.suffix(4))

        return ZStack {
            if visibleItems.isEmpty {
                placeholderCard
            } else {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { offset, item in
                    let distanceFromTop = visibleItems.count - 1 - offset
                    streamedCard(item: item, depth: distanceFromTop)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .identity
                        ))
                }
            }
        }
        .frame(height: 200)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: streamedItems.count)
    }

    private func streamedCard(item: StreamedCardItem, depth: Int) -> some View {
        let yOffset = Double(depth) * -8
        let scaleValue = 1.0 - Double(depth) * 0.04
        let opacityValue = depth == 0 ? 1.0 : max(1.0 - Double(depth) * 0.2, 0.4)

        return VStack {
            Text(item.content)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: presenter.deckColor.color.opacity(0.15), radius: 8, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            presenter.deckColor.color.opacity(0.5),
                            presenter.deckColor.color.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        }
        .rotationEffect(.degrees(item.rotation))
        .scaleEffect(scaleValue)
        .offset(x: item.xOffset, y: yOffset)
        .opacity(opacityValue)
        .zIndex(Double(100 - depth))
    }

    private var placeholderCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Preparing...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color(.separator), lineWidth: 1)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            if presenter.skippedBatches > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("\(presenter.skippedBatches) section(s) skipped")
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Text(progressPhrases[currentPhraseIndex % progressPhrases.count])
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.5), value: currentPhraseIndex)
                .onReceive(Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()) { _ in
                    currentPhraseIndex += 1
                }
        }
    }

    // MARK: - Helpers

    private var accessibilityLabel: String {
        var label = "Generating Flashcards. \(totalGenerated) of \(totalTarget) generated."
        if presenter.skippedBatches > 0 {
            label += " \(presenter.skippedBatches) sections skipped."
        }
        return label
    }
}

// MARK: - Streamed Card Item

private struct StreamedCardItem: Identifiable {
    let id: String
    let content: String
    let rotation: Double
    let xOffset: Double

    init(id: String, content: String) {
        self.id = id
        self.content = content
        var hasher = Hasher()
        hasher.combine(id)
        let hashValue = hasher.finalize()
        self.rotation = Double(abs(hashValue) % 13) - 6.0
        self.xOffset = Double(abs(hashValue / 7) % 9) - 4.0
    }
}
