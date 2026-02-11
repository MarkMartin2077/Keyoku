//
//  OnboardingPageView.swift
//  Keyoku
//
//

import SwiftUI

struct OnboardingPageView: View {

    let illustration: AnyView
    let title: String?
    let subtitle: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            illustration
                .frame(height: 260)
                .padding(.bottom, 40)

            VStack(spacing: 12) {
                if let title {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()
            Spacer()
        }
    }
}

#Preview("Full Data") {
    OnboardingPageView(
        illustration: AnyView(
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(.accent)
        ),
        title: "Create with Intelligence",
        subtitle: "Generate flashcards instantly from any text using on-device AI."
    )
}

#Preview("No Subtitle") {
    OnboardingPageView(
        illustration: AnyView(
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 80))
                .foregroundStyle(.purple)
        ),
        title: "Organize Your Way",
        subtitle: nil
    )
}

#Preview("No Illustration") {
    OnboardingPageView(
        illustration: AnyView(EmptyView()),
        title: "Track Your Progress",
        subtitle: "Study daily and watch your knowledge grow."
    )
}
