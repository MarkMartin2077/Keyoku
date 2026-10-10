//
//  QuizFeedbackView.swift
//  Keyoku
//

import SwiftUI
import SwiftfulUI

/// The content of the feedback sheet shown after answering a quiz question.
struct QuizFeedbackView: View {

    let isCorrect: Bool
    let correctAnswer: String?
    let explanation: String?
    let buttonTitle: String?
    let onContinue: (() -> Void)?

    private var tint: Color {
        isCorrect ? .green : .red
    }

    private var headline: String {
        if isCorrect { return "Correct" }
        guard let correctAnswer else { return "Not quite" }
        return "Not quite — it's \(correctAnswer)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(headline, systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3.bold())
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let explanation {
                Text(explanation)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(buttonTitle ?? "Continue")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tint)
                )
                .padding(.top, 4)
                .anyButton(.press) {
                    onContinue?()
                }
                .accessibilityIdentifier("QuizFeedbackContinueButton")
        }
        .padding(24)
    }
}

#Preview("Correct") {
    QuizFeedbackView(
        isCorrect: true,
        correctAnswer: "Hola",
        explanation: "\"Hola\" is the standard Spanish greeting.",
        buttonTitle: "Continue",
        onContinue: { }
    )
}

#Preview("Incorrect") {
    QuizFeedbackView(
        isCorrect: false,
        correctAnswer: "Ser",
        explanation: "\"Ser\" describes lasting characteristics, while \"estar\" describes states.",
        buttonTitle: "Continue",
        onContinue: { }
    )
}

#Preview("Last Question") {
    QuizFeedbackView(
        isCorrect: true,
        correctAnswer: "Por favor",
        explanation: "\"Por favor\" is used to make polite requests.",
        buttonTitle: "See Results",
        onContinue: { }
    )
}

#Preview("No Explanation") {
    QuizFeedbackView(
        isCorrect: false,
        correctAnswer: nil,
        explanation: nil,
        buttonTitle: nil,
        onContinue: nil
    )
}
