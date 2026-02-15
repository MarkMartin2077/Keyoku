//
//  CreateDeckGeneratingOverlay.swift
//  Keyoku
//
//  Created by Mark Martin on 2/13/26.
//

import SwiftUI

struct GenerationProgressData {
    let title: String
    let batchProgress: Int
    let batchTotal: Int
    let itemsGenerated: Int
    let itemsTarget: Int
    let statusText: String?
    let skipped: Int
    let tint: Color
}

struct CreateDeckGeneratingOverlay: View {

    let presenter: CreateDeckPresenter

    var body: some View {
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
                    Text(generatingTitle)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(generatingSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if presenter.hasProgress {
                    VStack(spacing: 16) {
                        if presenter.flashcardTotal > 0 {
                            progressSection(
                                data: GenerationProgressData(
                                    title: "Flashcards",
                                    batchProgress: presenter.flashcardProgress,
                                    batchTotal: presenter.flashcardTotal,
                                    itemsGenerated: presenter.flashcardItemsGenerated,
                                    itemsTarget: presenter.cardCount,
                                    statusText: presenter.flashcardStatusText,
                                    skipped: presenter.flashcardSkippedBatches,
                                    tint: .accent
                                )
                            )
                        }

                        if presenter.quizTotal > 0 {
                            progressSection(
                                data: GenerationProgressData(
                                    title: "Quiz",
                                    batchProgress: presenter.quizProgress,
                                    batchTotal: presenter.quizTotal,
                                    itemsGenerated: presenter.quizItemsGenerated,
                                    itemsTarget: presenter.questionCount,
                                    statusText: presenter.quizStatusText,
                                    skipped: presenter.quizSkippedBatches,
                                    tint: .green
                                )
                            )
                        }
                    }
                    .frame(maxWidth: 260)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }

                Spacer()

                Text(estimatedTimeText ?? "This may take a moment depending on the amount of source text.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .animation(.smooth, value: presenter.estimatedSecondsRemaining)
                    .padding(.bottom, 32)
            }
            .padding()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    // MARK: - Progress Section

    private func progressSection(data: GenerationProgressData) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(data.title)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(data.itemsGenerated) of \(data.itemsTarget)")
                    .font(.caption)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth, value: data.itemsGenerated)
            }
            .foregroundStyle(.secondary)

            ProgressView(value: Double(data.batchProgress), total: Double(data.batchTotal))
                .tint(data.tint)

            if let statusText = data.statusText {
                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if data.skipped > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("\(data.skipped) section(s) skipped — restricted")
                }
                .font(.caption2)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.numericText())
                .animation(.smooth, value: data.skipped)
            }
        }
    }

    // MARK: - Text Helpers

    private var accessibilityLabel: String {
        var label = "\(generatingTitle). \(generatingSubtitle)."
        if let statusText = presenter.flashcardStatusText {
            label += " Flashcards: \(statusText)."
        }
        if let statusText = presenter.quizStatusText {
            label += " Quiz: \(statusText)."
        }
        if presenter.skippedBatches > 0 {
            label += " \(presenter.skippedBatches) sections trimmed due to content restrictions."
        }
        if let timeText = estimatedTimeText {
            label += " \(timeText)."
        }
        return label
    }

    private var estimatedTimeText: String? {
        guard let seconds = presenter.estimatedSecondsRemaining, seconds > 0 else { return nil }
        if seconds < 60 {
            return "About \(seconds) seconds remaining"
        } else {
            let minutes = Int(ceil(Double(seconds) / 60.0))
            return "About \(minutes) minute\(minutes == 1 ? "" : "s") remaining"
        }
    }

    private var generatingTitle: String {
        switch presenter.contentType {
        case .flashcards: return "Generating Flashcards"
        case .quiz: return "Generating Quiz"
        case .both: return "Generating Content"
        }
    }

    private var generatingSubtitle: String {
        switch presenter.contentType {
        case .flashcards:
            return "Creating \(presenter.cardCount) cards for **\(presenter.deckName)**"
        case .quiz:
            return "Creating \(presenter.questionCount) questions for **\(presenter.deckName)**"
        case .both:
            return "Creating \(presenter.cardCount) cards and \(presenter.questionCount) questions for **\(presenter.deckName)**"
        }
    }
}
