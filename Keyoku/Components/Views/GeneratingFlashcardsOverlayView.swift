//
//  GeneratingFlashcardsOverlayView.swift
//  Keyoku
//

import SwiftUI
import SwiftfulUI

/// Full-screen progress for flashcard generation: streamed cards, real batch progress and a Cancel action.
struct GeneratingFlashcardsOverlayView: View {

    let previewCards: [FlashcardModel]
    let generatedCount: Int
    let targetCount: Int
    let batchNumber: Int?
    let batchTotal: Int?
    let modelName: String?
    let skippedMessage: String?
    let accentColor: Color
    let onCancel: (() -> Void)?

    private var visibleItems: [StreamedCardItem] {
        previewCards.suffix(4).map { StreamedCardItem(id: $0.flashcardId, content: $0.question) }
    }

    private var batchProgressText: String? {
        guard let batchNumber, let batchTotal, batchTotal > 0 else { return nil }
        return String(localized: "Section \(batchNumber) of \(batchTotal)")
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                    .padding(.top, 40)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel)

                cardStackSection
                    .padding(.horizontal, 32)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)

                footerSection
                    .padding(.bottom, 16)
            }
            .padding()
        }
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

            Text("\(generatedCount) of \(targetCount)")
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.smooth, value: generatedCount)

            if let modelName {
                Text(modelName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Card Stack

    private var cardStackSection: some View {
        ZStack {
            if visibleItems.isEmpty {
                placeholderCard
            } else {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { offset, item in
                    streamedCard(item: item, depth: visibleItems.count - 1 - offset)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .identity
                        ))
                }
            }
        }
        .frame(height: 200)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: previewCards.count)
    }

    private func streamedCard(item: StreamedCardItem, depth: Int) -> some View {
        let yOffset = Double(depth) * -8
        let scaleValue = 1.0 - Double(depth) * 0.04
        let opacityValue = depth == 0 ? 1.0 : max(1.0 - Double(depth) * 0.2, 0.4)

        return Text(item.content)
            .font(.subheadline)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .padding(.horizontal, 8)
            .padding(20)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.background)
                    .shadow(color: accentColor.opacity(0.15), radius: 8, y: 4)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        LinearGradient(
                            colors: [accentColor.opacity(0.5), accentColor.opacity(0.2)],
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
            if let batchProgressText {
                Text(batchProgressText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            if let skippedMessage {
                Label(skippedMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Text("AI-generated content can make mistakes. Verify accuracy with your source material.")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            if let onCancel {
                Text("Cancel")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .anyButton(.press) {
                        onCancel()
                    }
                    .accessibilityIdentifier("CancelGenerationButton")
                    .padding(.top, 12)
            }
        }
    }

    private var accessibilityLabel: String {
        var parts = [String(localized: "Generating Flashcards. \(generatedCount) of \(targetCount) generated.")]
        if let batchProgressText {
            parts.append(batchProgressText)
        }
        if let modelName {
            parts.append(modelName)
        }
        if let skippedMessage {
            parts.append(skippedMessage)
        }
        return parts.joined(separator: " ")
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
        // Seeded by id so a card keeps its tilt across re-renders.
        var hasher = Hasher()
        hasher.combine(id)
        let hashValue = hasher.finalize()
        self.rotation = Double(abs(hashValue) % 13) - 6.0
        self.xOffset = Double(abs(hashValue / 7) % 9) - 4.0
    }
}

private let previewSampleCards = [
    FlashcardModel(question: "What do mitochondria produce?", answer: "ATP, through cellular respiration."),
    FlashcardModel(question: "What do ribosomes build?", answer: "Proteins, from amino acids.")
]

#Preview("Streaming") {
    GeneratingFlashcardsOverlayView(
        previewCards: previewSampleCards,
        generatedCount: 2,
        targetCount: 10,
        batchNumber: 2,
        batchTotal: 4,
        modelName: "Private Cloud Compute",
        skippedMessage: nil,
        accentColor: .blue,
        onCancel: { }
    )
}

#Preview("Preparing") {
    GeneratingFlashcardsOverlayView(
        previewCards: [],
        generatedCount: 0,
        targetCount: 10,
        batchNumber: nil,
        batchTotal: nil,
        modelName: nil,
        skippedMessage: nil,
        accentColor: .green,
        onCancel: nil
    )
}

#Preview("With Skips") {
    GeneratingFlashcardsOverlayView(
        previewCards: previewSampleCards,
        generatedCount: 2,
        targetCount: 10,
        batchNumber: 4,
        batchTotal: 4,
        modelName: "On-device",
        skippedMessage: "1 section(s) skipped: unreadable text",
        accentColor: .orange,
        onCancel: { }
    )
}
