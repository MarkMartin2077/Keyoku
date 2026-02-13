//
//  QuizResultView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI
import SwiftfulUI

struct QuizResultView: View {

    let score: Int?
    let totalQuestions: Int?
    let quizName: String?
    var accentColor: Color = .blue
    let onRetakePressed: (() -> Void)?
    let onDonePressed: (() -> Void)?

    private var percentage: Double {
        guard let score, let totalQuestions, totalQuestions > 0 else { return 0 }
        return Double(score) / Double(totalQuestions) * 100
    }

    private var scoreColor: Color {
        if percentage >= 80 {
            return .green
        } else if percentage >= 60 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            scoreSection
            messageSection
            actionButtons

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Score Section

    private var scoreSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    if let score, let totalQuestions {
                        Text("\(score)/\(totalQuestions)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                    }

                    Text("\(Int(percentage))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(scoreColor)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(scoreAccessibilityLabel)

            if let quizName {
                Text(quizName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scoreAccessibilityLabel: String {
        guard let score, let totalQuestions else { return "No score" }
        return "\(score) out of \(totalQuestions) correct, \(Int(percentage)) percent"
    }

    // MARK: - Message Section

    private var messageSection: some View {
        VStack(spacing: 8) {
            Text(messageTitle)
                .font(.title2)
                .fontWeight(.bold)

            Text(messageSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var messageTitle: String {
        if percentage >= 80 {
            return "Great Job!"
        } else if percentage >= 60 {
            return "Good Effort!"
        } else {
            return "Keep Practicing!"
        }
    }

    private var messageSubtitle: String {
        if percentage >= 80 {
            return "You have a strong understanding of this material."
        } else if percentage >= 60 {
            return "You're on the right track. Review the topics you missed."
        } else {
            return "Consider reviewing the material and trying again."
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Retake Quiz")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor)
            )
            .accessibilityHint("Retake this quiz")
            .anyButton(.press) {
                onRetakePressed?()
            }

            HStack {
                Image(systemName: "checkmark")
                Text("Done")
            }
            .font(.headline)
            .foregroundStyle(accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(accentColor, lineWidth: 2)
            )
            .accessibilityHint("Return to previous screen")
            .anyButton(.press) {
                onDonePressed?()
            }
        }
    }
}

// MARK: - Previews

#Preview("High Score") {
    QuizResultView(
        score: 9,
        totalQuestions: 10,
        quizName: "World Geography",
        accentColor: .blue,
        onRetakePressed: { print("Retake") },
        onDonePressed: { print("Done") }
    )
}

#Preview("Medium Score") {
    QuizResultView(
        score: 7,
        totalQuestions: 10,
        quizName: "Science Basics",
        accentColor: .purple,
        onRetakePressed: { print("Retake") },
        onDonePressed: { print("Done") }
    )
}

#Preview("Low Score") {
    QuizResultView(
        score: 3,
        totalQuestions: 10,
        quizName: "Math Quiz",
        accentColor: .red,
        onRetakePressed: { print("Retake") },
        onDonePressed: { print("Done") }
    )
}

#Preview("No Data") {
    QuizResultView(
        score: nil,
        totalQuestions: nil,
        quizName: nil,
        onRetakePressed: nil,
        onDonePressed: nil
    )
}
