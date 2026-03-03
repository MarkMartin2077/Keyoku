//
//  HomeStillLearningSectionView.swift
//  Keyoku
//

import SwiftUI

struct HomeStillLearningSectionView: View {

    let cardCount: Int?
    let deckCount: Int?
    let onPressed: (() -> Void)?
    let onInfoPressed: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Still Learning")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .anyButton {
                        onInfoPressed?()
                    }
                    .accessibilityLabel("About Still Learning")
            }

            if let cardCount, let deckCount {
                practiceRow(cardCount: cardCount, deckCount: deckCount)
            }
        }
    }

    private func practiceRow(cardCount: Int, deckCount: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Practice \(cardCount) \(cardCount == 1 ? "card" : "cards")")
                    .font(.headline)

                Text("across \(deckCount) \(deckCount == 1 ? "deck" : "decks")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                }
        }
        .accessibilityLabel("Practice \(cardCount) still-learning cards across \(deckCount) decks")
        .accessibilityHint("Starts cross-deck practice session")
        .anyButton(.press) {
            onPressed?()
        }
    }
}

#Preview("With Data") {
    HomeStillLearningSectionView(
        cardCount: 14,
        deckCount: 3,
        onPressed: {},
        onInfoPressed: {}
    )
    .padding()
}

#Preview("Single Card, Single Deck") {
    HomeStillLearningSectionView(
        cardCount: 1,
        deckCount: 1,
        onPressed: {},
        onInfoPressed: nil
    )
    .padding()
}

#Preview("Nil Data") {
    HomeStillLearningSectionView(
        cardCount: nil,
        deckCount: nil,
        onPressed: nil,
        onInfoPressed: nil
    )
    .padding()
}
