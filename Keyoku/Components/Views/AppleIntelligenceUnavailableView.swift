//
//  AppleIntelligenceUnavailableView.swift
//  Keyoku
//
//  Created by Mark Martin on 2/20/26.
//

import SwiftUI
import FoundationModels

struct AppleIntelligenceUnavailableView: View {

    let reason: SystemLanguageModel.Availability.UnavailableReason
    let onOpenSettings: (() -> Void)?

    @Environment(\.openURL) private var openURL

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
        case .modelNotReady:
            Text("Apple Intelligence Unavailable")
                .font(.headline)
        @unknown default:
            Text("Apple Intelligence Unavailable")
                .font(.headline)
        }
    }

    @ViewBuilder
    private var description: some View {
        switch reason {
        case .deviceNotEligible:
            Text("This device doesn't support Apple Intelligence. An iPhone 15 Pro or later, or an iPad or Mac with an M1 chip or later, is required.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .appleIntelligenceNotEnabled:
            Text("Turn on Apple Intelligence in Settings to generate flashcards with AI.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .modelNotReady:
            Text("Apple Intelligence may be turned off or still setting up. Check that it's enabled in Settings, then try again.\n\nYou can still add cards manually in the meantime.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        @unknown default:
            Text("Apple Intelligence is currently unavailable. Please try again later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        if case .appleIntelligenceNotEnabled = reason {
            openSettingsContent
        } else if case .modelNotReady = reason {
            openSettingsContent
        }
    }

    private var openSettingsContent: some View {
        Button {
            if let action = onOpenSettings {
                action()
            } else if let url = URL(string: "App-Prefs:") {
                openURL(url)
            }
        } label: {
            Text("Open Settings")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .padding(.top, 4)
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
