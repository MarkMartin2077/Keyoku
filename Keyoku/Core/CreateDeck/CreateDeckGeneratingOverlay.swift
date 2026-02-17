//
//  CreateDeckGeneratingOverlay.swift
//  Keyoku
//
//  Created by Mark Martin on 2/13/26.
//

import SwiftUI

struct CreateDeckGeneratingOverlay: View {

    let presenter: CreateDeckPresenter

    private var streamedItems: [StreamedCardItem] {
        presenter.streamedFlashcards.map { card in
            StreamedCardItem(
                id: card.flashcardId,
                label: "Flashcard",
                content: card.question
            )
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

                Spacer()

                cardStackSection
                    .padding(.horizontal, 32)

                Spacer()

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

        return VStack(spacing: 12) {
            Text(item.label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(presenter.selectedColor.color)
                )

            Text(item.content)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: presenter.selectedColor.color.opacity(0.15), radius: 8, y: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            presenter.selectedColor.color.opacity(0.5),
                            presenter.selectedColor.color.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        }
        .rotationEffect(.degrees(item.rotation))
        .scaleEffect(scaleValue)
        .offset(y: yOffset)
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

            if let statusText = currentStatusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(estimatedTimeText ?? "This may take a moment depending on the amount of source text.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .contentTransition(.numericText())
                .animation(.smooth, value: presenter.estimatedSecondsRemaining)
        }
    }

    // MARK: - Text Helpers

    private var currentStatusText: String? {
        guard let flashcardStatus = presenter.flashcardStatusText, presenter.flashcardTotal > 0 else {
            return nil
        }
        return "Batch \(presenter.flashcardProgress)/\(presenter.flashcardTotal) — \(flashcardStatus)"
    }

    private var accessibilityLabel: String {
        var label = "Generating Flashcards. \(totalGenerated) of \(totalTarget) generated."
        if presenter.skippedBatches > 0 {
            label += " \(presenter.skippedBatches) sections skipped."
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
}

// MARK: - Streamed Card Item

private struct StreamedCardItem: Identifiable {
    let id: String
    let label: String
    let content: String
    let rotation: Double

    init(id: String, label: String, content: String) {
        self.id = id
        self.label = label
        self.content = content
        // Deterministic rotation based on id hash so it doesn't change on re-render
        var hasher = Hasher()
        hasher.combine(id)
        let hashValue = hasher.finalize()
        self.rotation = Double(hashValue % 7) - 3.0 // Range: -3 to +3 degrees
    }
}
