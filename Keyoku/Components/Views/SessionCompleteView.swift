//
//  SessionCompleteView.swift
//  Keyoku
//

import SwiftUI
import SwiftfulUI

struct SessionCompleteView: View {

    let learnedCount: Int
    let stillLearningCount: Int
    let newStreakCount: Int
    let nextReviewLabel: String?
    let deckColor: Color
    let onPracticeAgainPressed: () -> Void
    let onDonePressed: () -> Void

    @State private var showIcon: Bool = false
    @State private var showTitle: Bool = false
    @State private var showStats: Bool = false
    @State private var showExtras: Bool = false
    @State private var showButtons: Bool = false

    private var isPerfectSession: Bool { stillLearningCount == 0 }

    private var sessionTitle: String {
        isPerfectSession ? "Perfect Session!" : "Session Complete!"
    }

    private var sessionSubtitle: String {
        if isPerfectSession {
            let phrases = [
                "Every card mastered. You're unstoppable.",
                "Flawless. Your memory is locked in.",
                "100%! That's what dedication looks like.",
                "You nailed every single card."
            ]
            return phrases[learnedCount % phrases.count]
        } else {
            let phrases = [
                "Great work — keep showing up.",
                "Each session builds your memory.",
                "Consistency beats perfection.",
                "Progress over perfection."
            ]
            return phrases[learnedCount % phrases.count]
        }
    }

    var body: some View {
        ZStack {
            if isPerfectSession {
                ConfettiView()
            } else {
                RippleView(color: deckColor)
            }

            VStack(spacing: 0) {
                Spacer()

                // Icon
                celebrationIcon
                    .symbolEffect(.bounce, value: showIcon)
                    .scaleEffect(showIcon ? 1.0 : 0.3)
                    .opacity(showIcon ? 1.0 : 0.0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.55), value: showIcon)

                Spacer().frame(height: 28)

                // Title + subtitle
                VStack(spacing: 8) {
                    Text(sessionTitle)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(sessionSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .scaleEffect(showTitle ? 1.0 : 0.85)
                .opacity(showTitle ? 1.0 : 0.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showTitle)

                Spacer().frame(height: 36)

                // Stats card
                statsCard
                    .opacity(showStats ? 1.0 : 0.0)
                    .offset(y: showStats ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showStats)

                Spacer().frame(height: 20)

                // Streak + next review
                VStack(spacing: 12) {
                    if newStreakCount > 0 {
                        streakBadge
                    }

                    if let label = nextReviewLabel {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text("Next review · \(label)")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .scaleEffect(showExtras ? 1.0 : 0.85)
                .opacity(showExtras ? 1.0 : 0.0)
                .animation(.spring(response: 0.45, dampingFraction: 0.65), value: showExtras)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Text("Practice Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(deckColor)
                        )
                        .padding(.horizontal, 24)
                        .anyButton(.press) {
                            onPracticeAgainPressed()
                        }

                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .anyButton(.press) {
                            onDonePressed()
                        }
                        .accessibilityIdentifier("DoneButton")
                }
                .opacity(showButtons ? 1.0 : 0.0)
                .offset(y: showButtons ? 0 : 16)
                .animation(.easeOut(duration: 0.4), value: showButtons)

                Spacer().frame(height: 24)
            }
        }
        .onAppear {
            animateIn()
        }
    }

    // MARK: - Icon

    @ViewBuilder
    private var celebrationIcon: some View {
        ZStack {
            Circle()
                .fill((isPerfectSession ? Color.yellow : Color.green).opacity(0.15))
                .frame(width: 120, height: 120)

            if isPerfectSession {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("\(learnedCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
                Text("Learned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 1, height: 52)

            VStack(spacing: 6) {
                Text("\(stillLearningCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(stillLearningCount == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                    .contentTransition(.numericText())
                Text("Still Learning")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 24)
    }

    // MARK: - Streak Badge

    private var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
            Text("\(newStreakCount) day streak")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundStyle(.orange)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12), in: Capsule())
    }

    // MARK: - Animation

    private func animateIn() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            showIcon = true

            try? await Task.sleep(for: .milliseconds(250))
            showTitle = true

            try? await Task.sleep(for: .milliseconds(200))
            showStats = true

            try? await Task.sleep(for: .milliseconds(200))
            showExtras = true

            try? await Task.sleep(for: .milliseconds(150))
            showButtons = true
        }
    }
}

#Preview("Perfect Session") {
    SessionCompleteView(
        learnedCount: 12,
        stillLearningCount: 0,
        newStreakCount: 7,
        nextReviewLabel: "Tomorrow",
        deckColor: .blue,
        onPracticeAgainPressed: { },
        onDonePressed: { }
    )
}

#Preview("Partial Session") {
    SessionCompleteView(
        learnedCount: 8,
        stillLearningCount: 4,
        newStreakCount: 0,
        nextReviewLabel: "In 3 days",
        deckColor: .purple,
        onPracticeAgainPressed: { },
        onDonePressed: { }
    )
}

#Preview("No Extras") {
    SessionCompleteView(
        learnedCount: 5,
        stillLearningCount: 2,
        newStreakCount: 0,
        nextReviewLabel: nil,
        deckColor: .teal,
        onPracticeAgainPressed: { },
        onDonePressed: { }
    )
}
