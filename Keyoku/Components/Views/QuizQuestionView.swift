//
//  QuizQuestionView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/12/26.
//

import SwiftUI
import SwiftfulUI

struct QuizQuestionView: View {

    let questionText: String?
    let options: [String]?
    let questionType: QuestionType?
    let selectedIndex: Int?
    let correctAnswerIndex: Int?
    let isRevealed: Bool
    var accentColor: Color = .blue
    let onOptionSelected: ((Int) -> Void)?

    private let optionLetters = ["A", "B", "C", "D"]

    var body: some View {
        VStack(spacing: 0) {
            questionCard
            optionsList
        }
    }

    // MARK: - Question Card

    private var questionCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: accentColor.opacity(0.2), radius: 10, y: 5)
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [accentColor.opacity(0.5), accentColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                }

            VStack(spacing: 16) {
                if let questionType {
                    Text(questionType.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(accentColor)
                        )
                }

                if let questionText {
                    Text(questionText)
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(questionCardAccessibilityLabel)
        }
        .frame(minHeight: 200)
        .padding(.horizontal, 20)
    }

    // MARK: - Options List

    private var optionsList: some View {
        VStack(spacing: 12) {
            if let options {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    optionRow(index: index, text: option)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private func optionRow(index: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text(index < optionLetters.count ? optionLetters[index] : "\(index + 1)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(foregroundStyle(for: index))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(circleFill(for: index))
                )

            Text(text)
                .font(.body)
                .fontWeight(selectedIndex == index ? .semibold : .regular)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isRevealed, index == correctAnswerIndex {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            } else if isRevealed, selectedIndex == index, index != correctAnswerIndex {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(backgroundFill(for: index))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(borderColor(for: index), lineWidth: selectedIndex == index ? 2 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(optionAccessibilityLabel(index: index, text: text))
        .accessibilityHint(isRevealed ? "" : "Select this answer")
        .anyButton(.press) {
            if !isRevealed {
                onOptionSelected?(index)
            }
        }
        .disabled(isRevealed)
    }

    // MARK: - Accessibility Helpers

    private var questionCardAccessibilityLabel: String {
        var parts: [String] = []
        if let questionType {
            parts.append(questionType.displayName)
        }
        if let questionText {
            parts.append(questionText)
        }
        return parts.joined(separator: ", ")
    }

    private func optionAccessibilityLabel(index: Int, text: String) -> String {
        let letter = index < optionLetters.count ? optionLetters[index] : "\(index + 1)"
        var label = "Option \(letter), \(text)"
        if isRevealed {
            if index == correctAnswerIndex {
                label += ", correct answer"
            } else if selectedIndex == index {
                label += ", incorrect"
            }
        }
        return label
    }

    // MARK: - Styling Helpers

    private func backgroundFill(for index: Int) -> some ShapeStyle {
        if isRevealed {
            if index == correctAnswerIndex {
                return AnyShapeStyle(Color.green.opacity(0.1))
            } else if selectedIndex == index {
                return AnyShapeStyle(Color.red.opacity(0.1))
            }
        } else if selectedIndex == index {
            return AnyShapeStyle(accentColor.opacity(0.1))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    private func borderColor(for index: Int) -> Color {
        if isRevealed {
            if index == correctAnswerIndex {
                return .green
            } else if selectedIndex == index {
                return .red
            }
        } else if selectedIndex == index {
            return accentColor
        }
        return .secondary.opacity(0.3)
    }

    private func circleFill(for index: Int) -> some ShapeStyle {
        if isRevealed {
            if index == correctAnswerIndex {
                return AnyShapeStyle(Color.green.opacity(0.2))
            } else if selectedIndex == index {
                return AnyShapeStyle(Color.red.opacity(0.2))
            }
        } else if selectedIndex == index {
            return AnyShapeStyle(accentColor.opacity(0.2))
        }
        return AnyShapeStyle(Color.secondary.opacity(0.1))
    }

    private func foregroundStyle(for index: Int) -> Color {
        if isRevealed {
            if index == correctAnswerIndex {
                return .green
            } else if selectedIndex == index {
                return .red
            }
        } else if selectedIndex == index {
            return accentColor
        }
        return .secondary
    }
}

// MARK: - Previews

#Preview("Unanswered MC") {
    ScrollView {
        QuizQuestionView(
            questionText: "What is the capital of Japan?",
            options: ["Beijing", "Seoul", "Tokyo", "Bangkok"],
            questionType: .multipleChoice,
            selectedIndex: nil,
            correctAnswerIndex: 2,
            isRevealed: false,
            accentColor: .blue,
            onOptionSelected: { print("Selected \($0)") }
        )
    }
}

#Preview("Correct MC") {
    ScrollView {
        QuizQuestionView(
            questionText: "What is the capital of Japan?",
            options: ["Beijing", "Seoul", "Tokyo", "Bangkok"],
            questionType: .multipleChoice,
            selectedIndex: 2,
            correctAnswerIndex: 2,
            isRevealed: true,
            accentColor: .blue,
            onOptionSelected: nil
        )
    }
}

#Preview("Wrong MC") {
    ScrollView {
        QuizQuestionView(
            questionText: "What is the capital of Japan?",
            options: ["Beijing", "Seoul", "Tokyo", "Bangkok"],
            questionType: .multipleChoice,
            selectedIndex: 0,
            correctAnswerIndex: 2,
            isRevealed: true,
            accentColor: .blue,
            onOptionSelected: nil
        )
    }
}

#Preview("Unanswered T/F") {
    ScrollView {
        QuizQuestionView(
            questionText: "The Great Wall of China is visible from space.",
            options: ["True", "False"],
            questionType: .trueFalse,
            selectedIndex: nil,
            correctAnswerIndex: 1,
            isRevealed: false,
            accentColor: .purple,
            onOptionSelected: { print("Selected \($0)") }
        )
    }
}

#Preview("Correct T/F") {
    ScrollView {
        QuizQuestionView(
            questionText: "Water boils at 100 degrees Celsius at sea level.",
            options: ["True", "False"],
            questionType: .trueFalse,
            selectedIndex: 0,
            correctAnswerIndex: 0,
            isRevealed: true,
            accentColor: .green,
            onOptionSelected: nil
        )
    }
}
