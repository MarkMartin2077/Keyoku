//
//  AppleIntelligenceUnavailableView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/20/26.
//

import SwiftUI
import SwiftfulUI

struct AppleIntelligenceUnavailableView: View {

    /// What the unavailable feature would have made; sets the explanation's wording.
    enum Purpose {
        case flashcards
        case quizzes
    }

    let reason: UnavailableReason
    let onOpenSettings: (() -> Void)?
    var purpose: Purpose = .flashcards

    var body: some View {
        VStack(spacing: 16) {
            icon
            title
            description
            settingsButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .multilineTextAlignment(.center)
    }

    private var icon: some View {
        Image(systemName: "apple.intelligence")
            .font(.system(size: 40))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var title: some View {
        switch reason {
        case .deviceNotEligible:
            Text("Device Not Supported")
                .font(.headline)
        case .appleIntelligenceNotEnabled:
            Text("Apple Intelligence Not Enabled")
                .font(.headline)
        case .modelNotReady, .unknown:
            Text("Apple Intelligence Unavailable")
                .font(.headline)
        }
    }

    private var description: some View {
        Text(descriptionText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var descriptionText: String {
        switch (reason, purpose) {
        case (.deviceNotEligible, .flashcards):
            return String(localized: "This device doesn't support Apple Intelligence. An iPhone 15 Pro or later, or an iPad or Mac with an M1 chip or later, is required.")
        case (.deviceNotEligible, .quizzes):
            return String(localized: "This device doesn't support Apple Intelligence, so new quizzes can't be made. Saved quizzes still play.")
        case (.appleIntelligenceNotEnabled, .flashcards):
            return String(localized: "Turn on Apple Intelligence in Settings to generate flashcards with AI.")
        case (.appleIntelligenceNotEnabled, .quizzes):
            return String(localized: "Turn on Apple Intelligence in Settings to make new quizzes. Saved quizzes still play.")
        case (.modelNotReady, .flashcards):
            return String(localized: "Apple Intelligence may be turned off or still setting up. Check that it's enabled in Settings, then try again.\n\nYou can still add cards manually in the meantime.")
        case (.modelNotReady, .quizzes):
            return String(localized: "Apple Intelligence may be turned off or still setting up. Check that it's enabled in Settings, then try again. Saved quizzes still play.")
        case (.unknown, .flashcards):
            return String(localized: "Apple Intelligence is currently unavailable. Please try again later.")
        case (.unknown, .quizzes):
            return String(localized: "Apple Intelligence is currently unavailable, so new quizzes can't be made. Saved quizzes still play.")
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        if let onOpenSettings, reason == .appleIntelligenceNotEnabled || reason == .modelNotReady {
            Text("Open Settings")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                .anyButton(.press) {
                    onOpenSettings()
                }
                .padding(.top, 4)
        }
    }
}

#Preview("Device Not Eligible") {
    AppleIntelligenceUnavailableView(
        reason: .deviceNotEligible,
        onOpenSettings: nil
    )
}

#Preview("Not Enabled") {
    AppleIntelligenceUnavailableView(
        reason: .appleIntelligenceNotEnabled,
        onOpenSettings: { print("Open settings") }
    )
}

#Preview("Model Not Ready") {
    AppleIntelligenceUnavailableView(
        reason: .modelNotReady,
        onOpenSettings: nil
    )
}

#Preview("Quizzes, Not Enabled") {
    AppleIntelligenceUnavailableView(
        reason: .appleIntelligenceNotEnabled,
        onOpenSettings: { },
        purpose: .quizzes
    )
}
