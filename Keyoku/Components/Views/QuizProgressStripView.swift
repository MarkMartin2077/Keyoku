//
//  QuizProgressStripView.swift
//  Keyoku
//

import SwiftUI

/// The state of one question in a quiz attempt, as drawn by `QuizProgressStripView`.
enum QuizProgressSegment: Equatable, Sendable {
    case upcoming
    case current
    case correct
    case incorrect
}

/// A row of capsules, one per question, that turn green or red as questions are answered.
struct QuizProgressStripView: View {

    let segments: [QuizProgressSegment]
    let tint: Color?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Capsule()
                    .fill(color(for: segment))
                    .frame(height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: segments)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func color(for segment: QuizProgressSegment) -> Color {
        switch segment {
        case .upcoming:  return Color(.systemGray5)
        case .current:   return tint ?? .accentColor
        case .correct:   return .green
        case .incorrect: return .red
        }
    }

    private var accessibilityText: String {
        let answered = segments.filter { $0 == .correct || $0 == .incorrect }.count
        return "\(answered) of \(segments.count) questions answered"
    }
}

#Preview("Mid Quiz") {
    QuizProgressStripView(
        segments: [.correct, .incorrect, .correct, .current, .upcoming, .upcoming],
        tint: DeckColor.blue.color
    )
    .padding()
}

#Preview("Just Started") {
    QuizProgressStripView(
        segments: [.current, .upcoming, .upcoming, .upcoming, .upcoming],
        tint: DeckColor.purple.color
    )
    .padding()
}

#Preview("All Answered") {
    QuizProgressStripView(
        segments: [.correct, .correct, .incorrect, .correct, .correct],
        tint: nil
    )
    .padding()
}

#Preview("Empty") {
    QuizProgressStripView(segments: [], tint: nil)
        .padding()
}
