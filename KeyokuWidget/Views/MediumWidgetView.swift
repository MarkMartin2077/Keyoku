//
//  MediumWidgetView.swift
//  KeyokuWidget
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            statsRow

            if data.recentDecks.isEmpty {
                emptyState
            } else {
                decksRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

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

            HStack(spacing: 4) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text("\(data.quizCount) \(data.quizCount == 1 ? "quiz" : "quizzes")")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }

    private var decksRow: some View {
        HStack(spacing: 8) {
            ForEach(data.recentDecks) { deck in
                Link(destination: URL(string: "keyoku://deck?id=\(deck.id)")!) {
                    WidgetDeckCardView(deck: deck)
                }
            }

            Link(destination: URL(string: "keyoku://create")!) {
                createButton
            }
        }
    }

    private var createButton: some View {
        VStack(spacing: 4) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)

            Text("Create")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.1))
        }
    }

    private var emptyState: some View {
        Link(destination: URL(string: "keyoku://create")!) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Create your first deck")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
            }
        }
    }
}
