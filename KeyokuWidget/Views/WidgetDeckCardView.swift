//
//  WidgetDeckCardView.swift
//  KeyokuWidget
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI

struct WidgetDeckCardView: View {
    let deck: WidgetDeckItem

    private var cardColor: Color {
        WidgetColorHelper.color(from: deck.colorRawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deck.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Text("\(deck.cardCount) card\(deck.cardCount == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [cardColor, cardColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}
