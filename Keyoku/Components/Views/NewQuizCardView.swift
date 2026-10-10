//
//  NewQuizCardView.swift
//  Keyoku
//

import SwiftUI
import SwiftfulUI

/// What the "+ New Quiz" card at the front of a deck's quiz strip shows.
enum NewQuizCardStatus: Equatable, Sendable {
    /// A new quiz can be made; tapping opens the New Quiz sheet.
    case ready
    /// A quiz is being made. Shows how many questions are written so far; tapping cancels.
    case generating(questionCount: Int)
    /// Apple Intelligence is unavailable, so the card is greyed out and does nothing.
    case unavailable

    var analyticsName: String {
        switch self {
        case .ready: return "ready"
        case .generating: return "generating"
        case .unavailable: return "unavailable"
        }
    }
}

/// The dashed card that leads a deck's quiz strip: makes a new quiz, or shows one being made.
struct NewQuizCardView: View {

    let status: NewQuizCardStatus
    let tint: Color
    let onTap: (() -> Void)?

    @ScaledMetric(relativeTo: .subheadline) private var cardWidth: CGFloat = 130

    var body: some View {
        content
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .padding(12)
            .frame(width: cardWidth)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(foreground, style: StrokeStyle(lineWidth: 2, dash: [6]))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .anyButton(.press) {
                onTap?()
            }
            .disabled(status == .unavailable)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .ready, .unavailable:
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title)
                Text("New Quiz")
                    .font(.subheadline.bold())
            }
        case .generating(let questionCount):
            VStack(spacing: 6) {
                ProgressView()
                    .tint(tint)
                Text("Making your quiz…")
                    .font(.subheadline.bold())
                Text("^[\(questionCount) question](inflect: true)")
                    .font(.caption)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("Tap to cancel")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var foreground: Color {
        status == .unavailable ? .secondary : tint
    }

    private var accessibilityLabel: String {
        switch status {
        case .ready:
            return String(localized: "New Quiz")
        case .generating(let questionCount):
            return String(AttributedString(localized: "Making your quiz, ^[\(questionCount) question](inflect: true) so far").characters)
        case .unavailable:
            return String(localized: "New Quiz, unavailable")
        }
    }

    private var accessibilityHint: String {
        switch status {
        case .ready:
            return String(localized: "Choose how many questions, then make a quiz from this deck's source text")
        case .generating:
            return String(localized: "Cancels making the quiz. Nothing is saved.")
        case .unavailable:
            return String(localized: "Apple Intelligence is needed to make new quizzes")
        }
    }
}

#Preview("Ready") {
    NewQuizCardView(status: .ready, tint: .orange, onTap: { })
        .frame(height: 150)
        .padding()
}

#Preview("Generating") {
    NewQuizCardView(status: .generating(questionCount: 6), tint: .orange, onTap: { })
        .frame(height: 150)
        .padding()
}

#Preview("Generating, none yet") {
    NewQuizCardView(status: .generating(questionCount: 0), tint: .blue, onTap: nil)
        .frame(height: 150)
        .padding()
}

#Preview("Unavailable") {
    NewQuizCardView(status: .unavailable, tint: .orange, onTap: nil)
        .frame(height: 150)
        .padding()
}
