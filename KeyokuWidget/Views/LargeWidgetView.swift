//
//  LargeWidgetView.swift
//  KeyokuWidget
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statsRow

            decksSection

            Link(destination: URL(string: "keyoku://create")!) {
                createButton
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text("\(data.deckCount) \(data.deckCount == 1 ? "deck" : "decks")")
                    .font(.caption)
                    .fontWeight(.medium)
            }

            HStack(spacing: 4) {
                Image(systemName: "doc.text.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text("\(data.totalCardCount) \(data.totalCardCount == 1 ? "card" : "cards")")
                    .font(.caption)
                    .fontWeight(.medium)
            }

        }
    }

    // MARK: - Decks

    private var decksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Decks")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if data.recentDecks.isEmpty {
                emptyRow(text: "No decks yet")
            } else {
                HStack(spacing: 8) {
                    ForEach(data.recentDecks) { deck in
                        Link(destination: URL(string: "keyoku://deck?id=\(deck.id)")!) {
                            WidgetDeckCardView(deck: deck)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func emptyRow(text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private var createButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(.white)

            Text("Create New")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}
