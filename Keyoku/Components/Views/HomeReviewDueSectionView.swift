//
//  HomeReviewDueSectionView.swift
//  Keyoku
//

import SwiftUI

struct HomeReviewDueSectionView: View {

    let decks: [DeckModel]
    let onDeckPressed: ((DeckModel) -> Void)?
    let onInfoPressed: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text("Review Due")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .anyButton {
                        onInfoPressed?()
                    }
            }

            if !decks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(decks) { deck in
                            dueDeckTile(deck: deck)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private func dueDeckTile(deck: DeckModel) -> some View {
        let dueCount = deck.flashcards.filter { $0.isLearned && $0.isDue }.count

        return VStack(alignment: .leading, spacing: 8) {
            Text(deck.name)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            if dueCount > 0 {
                Text("\(dueCount) due")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.25), in: Capsule())
            }
        }
        .padding()
        .frame(width: 165, height: 110, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(deck.color.color)
        }
        .accessibilityLabel("\(deck.name), \(dueCount) cards due for review")
        .accessibilityHint("Opens deck detail")
        .anyButton(.press) {
            onDeckPressed?(deck)
        }
    }
}

#Preview("With Due Decks") {
    HomeReviewDueSectionView(
        decks: DeckModel.mocks.filter { !$0.flashcards.filter { $0.isLearned }.isEmpty },
        onDeckPressed: { _ in },
        onInfoPressed: {}
    )
    .padding()
}

#Preview("No Decks") {
    HomeReviewDueSectionView(
        decks: [],
        onDeckPressed: nil,
        onInfoPressed: nil
    )
    .padding()
}
