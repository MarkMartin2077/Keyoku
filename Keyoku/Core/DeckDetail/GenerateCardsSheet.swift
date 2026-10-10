//
//  GenerateCardsSheet.swift
//  Keyoku
//
//  Created by Mark Martin on 2/17/26.
//

import SwiftUI
import SwiftfulUI
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

    @ViewBuilder
    private var formContent: some View {
        if let reason = presenter.unavailableReason {
            Form {
                Section {
                    AppleIntelligenceUnavailableView(
                        reason: reason,
                        onOpenSettings: presenter.onOpenSettingsPressed
                    )
                }
            }
        } else {
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

            if presenter.sourceTextTooShort {
                let remaining = DeckDetailPresenter.minimumSourceTextLength - presenter.trimmedSourceTextLength
                Text("Add at least \(remaining) more characters. Paste notes, textbook excerpts, or study material to generate quality flashcards.")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
        GeneratingFlashcardsOverlayView(
            previewCards: presenter.progress.previewCards,
            generatedCount: presenter.progress.cards.count,
            targetCount: presenter.cardCount,
            batchNumber: presenter.progress.currentBatchNumber,
            batchTotal: presenter.progress.totalBatchCount,
            modelName: presenter.progress.model?.displayName,
            skippedMessage: presenter.progress.skippedSummary,
            accentColor: presenter.deckColor.color,
            onCancel: presenter.onCancelGenerationPressed
        )
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

                if let skippedSummary = presenter.progress.skippedSummary {
                    Text(skippedSummary)
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
