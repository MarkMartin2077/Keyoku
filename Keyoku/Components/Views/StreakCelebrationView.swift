//
//  StreakCelebrationView.swift
//  Keyoku
//
//

import SwiftUI
import SwiftfulUI

struct StreakCelebrationView: View {

    let streakCount: Int?
    let onDismiss: (() -> Void)?

    @State private var showFlame: Bool = false
    @State private var showCount: Bool = false
    @State private var showSubtitle: Bool = false
    @State private var showButton: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                flameIcon
                streakCountLabel
                subtitleLabel

                Spacer()

                dismissButton
            }
            .padding(32)
        }
        .onAppear {
            animateIn()
        }
    }

    // MARK: - Flame Icon

    private var flameIcon: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 100))
            .foregroundStyle(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .symbolEffect(.bounce, value: showFlame)
            .scaleEffect(showFlame ? 1.0 : 0.3)
            .opacity(showFlame ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: showFlame)
    }

    // MARK: - Streak Count

    private var streakCountLabel: some View {
        VStack(spacing: 4) {
            if let streakCount {
                Text("\(streakCount)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            Text("Day Streak!")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .scaleEffect(showCount ? 1.0 : 0.5)
        .opacity(showCount ? 1.0 : 0.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCount)
    }

    // MARK: - Subtitle

    private var subtitleText: String {
        let count = streakCount ?? 1
        let phrases: [String]

        switch count {
        case 1:
            phrases = [
                "And so it begins!",
                "The first step is the hardest!",
                "A great start!"
            ]
        case 2...4:
            phrases = [
                "You're building momentum!",
                "Consistency is key!",
                "Keep showing up!",
                "One day at a time!"
            ]
        case 5...9:
            phrases = [
                "You're on fire! Keep it up.",
                "Impressive dedication!",
                "You're in the zone!",
                "Nothing can stop you now!"
            ]
        case 10...29:
            phrases = [
                "Double digits! Incredible!",
                "You're unstoppable!",
                "What a streak!",
                "Consistency pays off!"
            ]
        default:
            phrases = [
                "Legendary commitment!",
                "You're a studying machine!",
                "Absolutely unstoppable!",
                "Your dedication is inspiring!"
            ]
        }

        return phrases[count % phrases.count]
    }

    private var subtitleLabel: some View {
        Text(subtitleText)
            .font(.body)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .opacity(showSubtitle ? 1.0 : 0.0)
            .animation(.easeIn(duration: 0.4), value: showSubtitle)
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Text("Continue")
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .opacity(showButton ? 1.0 : 0.0)
            .animation(.easeIn(duration: 0.3), value: showButton)
            .anyButton(.press) {
                onDismiss?()
            }
    }

    // MARK: - Animation

    private func animateIn() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            showFlame = true

            try? await Task.sleep(for: .milliseconds(400))
            showCount = true

            try? await Task.sleep(for: .milliseconds(300))
            showSubtitle = true

            try? await Task.sleep(for: .milliseconds(200))
            showButton = true
        }
    }
}

#Preview("Streak 5") {
    StreakCelebrationView(
        streakCount: 5,
        onDismiss: { }
    )
}

#Preview("Streak 30") {
    StreakCelebrationView(
        streakCount: 30,
        onDismiss: { }
    )
}

#Preview("Streak 1") {
    StreakCelebrationView(
        streakCount: 1,
        onDismiss: { }
    )
}

#Preview("No Count") {
    StreakCelebrationView(
        streakCount: nil,
        onDismiss: nil
    )
}
