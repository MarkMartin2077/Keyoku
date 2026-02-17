//
//  SmallWidgetView.swift
//  KeyokuWidget
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let data: WidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("Keyoku")
                    .font(.headline)
                    .fontWeight(.bold)
            }

            VStack(alignment: .leading, spacing: 6) {
                statRow(
                    icon: "rectangle.stack.fill",
                    value: "\(data.deckCount)",
                    label: data.deckCount == 1 ? "deck" : "decks"
                )

                statRow(
                    icon: "doc.text.fill",
                    value: "\(data.totalCardCount)",
                    label: data.totalCardCount == 1 ? "card" : "cards"
                )

            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func statRow(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
