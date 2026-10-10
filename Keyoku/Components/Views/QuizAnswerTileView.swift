//
//  QuizAnswerTileView.swift
//  Keyoku
//

import SwiftUI
import SwiftfulUI

/// How an answer tile is drawn before and after the question is answered.
enum QuizAnswerState: Equatable, Sendable {
    /// Not answered yet; the tile is tappable.
    case idle
    /// The correct answer, revealed after any pick.
    case correct
    /// The learner's wrong pick.
    case incorrect
    /// Any other answer once the question is locked.
    case dimmed
}

/// One answer in the quiz's 2×2 grid. Tapping only fires while the state is `.idle`.
struct QuizAnswerTileView: View {

    let text: String?
    let state: QuizAnswerState
    let onTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 6) {
            if let iconName {
                Image(systemName: iconName)
                    .font(.headline)
            }
            Text(text ?? "")
                .font(.headline)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(foreground)
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 96)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(border, lineWidth: 2)
        )
        .opacity(state == .dimmed ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.2), value: state)
        .anyButton(.press) {
            guard state == .idle else { return }
            onTap?()
        }
        .allowsHitTesting(state == .idle)
        .accessibilityLabel(accessibilityText)
    }

    private var iconName: String? {
        switch state {
        case .correct:   return "checkmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        case .idle, .dimmed: return nil
        }
    }

    private var foreground: Color {
        switch state {
        case .correct:   return .green
        case .incorrect: return .red
        case .idle, .dimmed: return .primary
        }
    }

    private var background: Color {
        switch state {
        case .correct:   return .green.opacity(0.18)
        case .incorrect: return .red.opacity(0.18)
        case .idle, .dimmed: return Color(.secondarySystemBackground)
        }
    }

    private var border: Color {
        switch state {
        case .correct:   return .green
        case .incorrect: return .red
        case .idle, .dimmed: return .clear
        }
    }

    private var accessibilityText: String {
        let answer = text ?? ""
        switch state {
        case .idle, .dimmed: return answer
        case .correct:       return "\(answer), correct answer"
        case .incorrect:     return "\(answer), your answer, incorrect"
        }
    }
}

#Preview("All States") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        QuizAnswerTileView(text: "Hola", state: .correct, onTap: nil)
        QuizAnswerTileView(text: "Adiós", state: .incorrect, onTap: nil)
        QuizAnswerTileView(text: "Gracias", state: .dimmed, onTap: nil)
        QuizAnswerTileView(text: "Por favor", state: .idle, onTap: { })
    }
    .padding()
}

#Preview("Unanswered") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        QuizAnswerTileView(text: "Mitochondria", state: .idle, onTap: { })
        QuizAnswerTileView(text: "Ribosome", state: .idle, onTap: { })
        QuizAnswerTileView(text: "A much longer answer that wraps over several lines", state: .idle, onTap: { })
        QuizAnswerTileView(text: "Nucleus", state: .idle, onTap: { })
    }
    .padding()
}

#Preview("No Text") {
    QuizAnswerTileView(text: nil, state: .idle, onTap: nil)
        .padding()
}
