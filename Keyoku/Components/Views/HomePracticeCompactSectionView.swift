//
//  HomePracticeCompactSectionView.swift
//  Keyoku
//

import SwiftUI

struct HomePracticeCompactSectionView: View {

    let dueCount: Int?
    let hasDue: Bool
    let stillLearningCount: Int?
    let hasStillLearning: Bool
    let onDueTapped: (() -> Void)?
    let onStillLearningTapped: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Practice")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                if hasDue, let dueCount {
                    compactRow(
                        icon: "clock.badge.checkmark",
                        iconColor: .green,
                        label: "\(dueCount) \(dueCount == 1 ? "card" : "cards") due for review",
                        showDivider: hasStillLearning,
                        onTap: onDueTapped
                    )
                }

                if hasStillLearning, let stillLearningCount {
                    compactRow(
                        icon: "arrow.trianglehead.2.clockwise.rotate.90",
                        iconColor: .orange,
                        label: "\(stillLearningCount) \(stillLearningCount == 1 ? "card" : "cards") still learning",
                        showDivider: false,
                        onTap: onStillLearningTapped
                    )
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                    }
            }
        }
    }

    private func compactRow(icon: String, iconColor: Color, label: String, showDivider: Bool, onTap: (() -> Void)?) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .accessibilityLabel(label)
            .accessibilityHint("Start practice session")
            .anyButton(.press) {
                onTap?()
            }

            if showDivider {
                Divider()
                    .padding(.leading, 52)
            }
        }
    }
}

#Preview("Both Rows") {
    HomePracticeCompactSectionView(
        dueCount: 8,
        hasDue: true,
        stillLearningCount: 14,
        hasStillLearning: true,
        onDueTapped: {},
        onStillLearningTapped: {}
    )
    .padding()
}

#Preview("Due Only") {
    HomePracticeCompactSectionView(
        dueCount: 5,
        hasDue: true,
        stillLearningCount: nil,
        hasStillLearning: false,
        onDueTapped: {},
        onStillLearningTapped: nil
    )
    .padding()
}

#Preview("Still Learning Only") {
    HomePracticeCompactSectionView(
        dueCount: nil,
        hasDue: false,
        stillLearningCount: 20,
        hasStillLearning: true,
        onDueTapped: nil,
        onStillLearningTapped: {}
    )
    .padding()
}

#Preview("Single Card") {
    HomePracticeCompactSectionView(
        dueCount: 1,
        hasDue: true,
        stillLearningCount: 1,
        hasStillLearning: true,
        onDueTapped: {},
        onStillLearningTapped: {}
    )
    .padding()
}
