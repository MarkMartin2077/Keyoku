//
//  QuizScoreRingView.swift
//  Keyoku
//

import SwiftUI

/// A ring filled to `score / total` with the score written in the middle.
struct QuizScoreRingView: View {

    let score: Int?
    let total: Int?
    let tint: Color?

    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 180

    private var fraction: Double {
        guard let score, let total, total > 0 else { return 0 }
        return min(1, max(0, Double(score) / Double(total)))
    }

    private var ringColor: Color {
        tint ?? .accentColor
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: 14)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: fraction)

            if let score, let total {
                Text("\(score)/\(total)")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .contentTransition(.numericText())
            }
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let score, let total else { return "No score" }
        return "Scored \(score) out of \(total)"
    }
}

#Preview("Perfect") {
    QuizScoreRingView(score: 5, total: 5, tint: DeckColor.green.color)
}

#Preview("Partial") {
    QuizScoreRingView(score: 3, total: 10, tint: DeckColor.purple.color)
}

#Preview("Zero") {
    QuizScoreRingView(score: 0, total: 8, tint: nil)
}

#Preview("No Data") {
    QuizScoreRingView(score: nil, total: nil, tint: nil)
}
