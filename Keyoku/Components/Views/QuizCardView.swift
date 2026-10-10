//
//  QuizCardView.swift
//  Keyoku
//

import SwiftUI
import SwiftfulUI

/// One saved quiz in a deck's quiz strip: title, best score ("n/total" or "New"),
/// and question count with how long ago it was made. Long-press offers Delete.
struct QuizCardView: View {

    let title: String?
    let bestScore: Int?
    let questionCount: Int?
    let createdAt: Date?
    let tint: Color
    let onTap: (() -> Void)?
    let onDelete: (() -> Void)?

    @ScaledMetric(relativeTo: .subheadline) private var cardWidth: CGFloat = 150
    @ScaledMetric(relativeTo: .subheadline) private var cardMinHeight: CGFloat = 130

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(3)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }

            Text(scoreText)
                .font(.title3.bold())
                .foregroundStyle(bestScore == nil ? Color.secondary : tint)
                .monospacedDigit()

            if let detailText {
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: cardWidth, alignment: .leading)
        .frame(minHeight: cardMinHeight, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(tint.opacity(0.12))
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .anyButton(.press) {
            onTap?()
        }
        .contextMenu {
            if let onDelete {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    onDelete()
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(String(localized: "Starts the quiz"))
        .accessibilityActions {
            if let onDelete {
                Button("Delete") {
                    onDelete()
                }
            }
        }
    }

    private var scoreText: String {
        guard let bestScore, let questionCount else {
            return String(localized: "New")
        }
        return "\(bestScore)/\(questionCount)"
    }

    private var detailText: String? {
        switch (questionCount, createdAt) {
        case let (count?, date?):
            return String(AttributedString(localized: "^[\(count) question](inflect: true) · \(date.formatted(.relative(presentation: .named)))").characters)
        case let (count?, nil):
            return String(AttributedString(localized: "^[\(count) question](inflect: true)").characters)
        case let (nil, date?):
            return date.formatted(.relative(presentation: .named))
        case (nil, nil):
            return nil
        }
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if let title {
            parts.append(title)
        }
        if let bestScore, let questionCount {
            parts.append(String(localized: "Best score \(bestScore) out of \(questionCount)"))
        } else {
            parts.append(String(localized: "Not played yet"))
        }
        if let detailText {
            parts.append(detailText)
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Played") {
    QuizCardView(
        title: "Spanish Greetings Quiz",
        bestScore: 4,
        questionCount: 5,
        createdAt: .now.addingTimeInterval(-7200),
        tint: .orange,
        onTap: { },
        onDelete: { }
    )
    .frame(height: 150)
    .padding()
}

#Preview("New") {
    QuizCardView(
        title: "Cell Biology Basics",
        bestScore: nil,
        questionCount: 10,
        createdAt: .now.addingTimeInterval(-172_800),
        tint: .blue,
        onTap: { },
        onDelete: { }
    )
    .frame(height: 150)
    .padding()
}

#Preview("Long Title") {
    QuizCardView(
        title: "The Causes and Lasting Consequences of the French Revolution",
        bestScore: 12,
        questionCount: 20,
        createdAt: .now,
        tint: .purple,
        onTap: { },
        onDelete: nil
    )
    .frame(height: 150)
    .padding()
}

#Preview("No Data") {
    QuizCardView(
        title: nil,
        bestScore: nil,
        questionCount: nil,
        createdAt: nil,
        tint: .green,
        onTap: nil,
        onDelete: nil
    )
    .frame(height: 150)
    .padding()
}
