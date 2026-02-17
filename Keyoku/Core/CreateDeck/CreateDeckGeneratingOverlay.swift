//
//  CreateDeckGeneratingOverlay.swift
//  Keyoku
//
//  Created by Mark Martin on 2/13/26.
//

import SwiftUI
import Combine

struct CreateDeckGeneratingOverlay: View {

    let presenter: CreateDeckPresenter

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
            StreamedCardItem(
                id: card.flashcardId,
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

    // MARK: - Text Helpers

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
        // Deterministic rotation based on id hash so it doesn't change on re-render
        var hasher = Hasher()
        hasher.combine(id)
        let hashValue = hasher.finalize()
        self.rotation = Double(abs(hashValue) % 13) - 6.0 // Range: -6 to +6 degrees
        self.xOffset = Double(abs(hashValue / 7) % 9) - 4.0 // Range: -4 to +4 points
    }
}
