//
//  WelcomeView.swift
//  Keyoku
//
//
//
import SwiftUI
import SwiftfulUI

struct WelcomeDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct WelcomeView: View {

    @State var presenter: WelcomePresenter
    let delegate: WelcomeDelegate

    @State private var appeared = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()

                heroIllustration
                    .padding(.bottom, 32)

                titleSection
                    .padding(.bottom, 40)

                ctaButtons
                    .padding(.horizontal, 24)

                policyLinks
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            // Gradient orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -80, y: -300)
                .blur(radius: 60)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.2), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: 120, y: -180)
                .blur(radius: 50)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.indigo.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: 60, y: 100)
                .blur(radius: 40)
        }
    }

    // MARK: - Hero Illustration

    private var heroIllustration: some View {
        ZStack {
            // Back card
            floatingCard(
                color: .purple,
                rotation: -8,
                offset: CGSize(width: -28, height: 12),
                frontText: "A",
                backText: nil
            )

            // Middle card
            floatingCard(
                color: .indigo,
                rotation: 4,
                offset: CGSize(width: 24, height: -8),
                frontText: "Q",
                backText: nil
            )

            // Front card
            floatingCard(
                color: .accentColor,
                rotation: 0,
                offset: .zero,
                frontText: nil,
                backText: nil,
                isMain: true
            )
        }
        .frame(height: 220)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 30)
    }

    private func floatingCard(
        color: Color,
        rotation: Double,
        offset: CGSize,
        frontText: String?,
        backText: String?,
        isMain: Bool = false
    ) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: isMain ? 180 : 160, height: isMain ? 120 : 105)
            .overlay {
                if isMain {
                    VStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.white)

                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.4))
                                    .frame(height: 4)
                            }
                        }
                        .padding(.horizontal, 24)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.25))
                            .frame(width: 80, height: 4)
                    }
                } else if let frontText {
                    Text(frontText)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .shadow(color: color.opacity(0.3), radius: 16, x: 0, y: 8)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 10) {
            Text("Keyoku")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text("Study smarter with AI-powered flashcards")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 40)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - CTA Buttons

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            Text("Get Started")
                .callToActionButton(cornerRadius: 14)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .anyButton(.press) {
                    presenter.onGetStartedPressed()
                }
                .accessibilityIdentifier("StartButton")
                .frame(maxWidth: 500)

            Text("Already have an account? **Sign in**")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(8)
                .tappableBackground()
                .anyButton(.press) {
                    presenter.onSignInPressed()
                }
                .lineLimit(1)
                .minimumScaleFactor(0.3)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    // MARK: - Policy Links

    private var policyLinks: some View {
        HStack(spacing: 8) {
            Link(destination: URL(string: Constants.termsOfServiceUrlString)!) {
                Text("Terms of Service")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 3, height: 3)
            Link(destination: URL(string: Constants.privacyPolicyUrlString)!) {
                Text("Privacy Policy")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return builder.onboardingFlow()
}

extension CoreBuilder {

    func onboardingFlow() -> some View {
        RouterView { router in
            welcomeView(router: router)
        }
    }

    private func welcomeView(router: AnyRouter, delegate: WelcomeDelegate = WelcomeDelegate()) -> some View {
        WelcomeView(
            presenter: WelcomePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

}
