//
//  FirstDeckCelebrationView.swift
//  Keyoku
//
//

import SwiftUI
import SwiftfulUI

struct FirstDeckCelebrationView: View {

    let onDismiss: (() -> Void)?

    @State private var showIcon: Bool = false
    @State private var showTitle: Bool = false
    @State private var showSubtitle: Bool = false
    @State private var showButton: Bool = false

    private var subtitleText: String {
        let phrases = [
            "Your learning journey starts now!",
            "Great things start with a single step!",
            "You're all set to start studying!",
            "Time to unlock your potential!",
            "Knowledge awaits — let's dive in!"
        ]
        return phrases[Int.random(in: 0..<phrases.count)]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                deckIcon
                titleLabel
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

    // MARK: - Icon

    private var deckIcon: some View {
        Image(systemName: "rectangle.stack.fill")
            .font(.system(size: 90))
            .foregroundStyle(
                LinearGradient(
                    colors: [.accent, .accent.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .symbolEffect(.bounce, value: showIcon)
            .scaleEffect(showIcon ? 1.0 : 0.3)
            .opacity(showIcon ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: showIcon)
    }

    // MARK: - Title

    private var titleLabel: some View {
        Text("First Deck Created!")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .scaleEffect(showTitle ? 1.0 : 0.5)
            .opacity(showTitle ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showTitle)
    }

    // MARK: - Subtitle

    private var subtitleLabel: some View {
        Text(subtitleText)
            .font(.body)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .opacity(showSubtitle ? 1.0 : 0.0)
            .animation(.easeIn(duration: 0.4), value: showSubtitle)
    }

    // MARK: - Button

    private var dismissButton: some View {
        Text("Let's Go")
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.accent, .accent.opacity(0.8)],
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
            showIcon = true

            try? await Task.sleep(for: .milliseconds(400))
            showTitle = true

            try? await Task.sleep(for: .milliseconds(300))
            showSubtitle = true

            try? await Task.sleep(for: .milliseconds(200))
            showButton = true
        }
    }
}

#Preview("First Deck") {
    FirstDeckCelebrationView(
        onDismiss: { }
    )
}
