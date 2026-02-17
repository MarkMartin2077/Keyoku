//
//  OnboardingCompletedView.swift
//  Keyoku
//
//
//

import SwiftUI
import SwiftfulUI

struct OnboardingCompletedDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct OnboardingCompletedView: View {

    @State var presenter: OnboardingCompletedPresenter
    var delegate: OnboardingCompletedDelegate = OnboardingCompletedDelegate()

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                TabView(selection: $presenter.currentPage) {
                    page1.tag(0)
                    page2.tag(1)
                    page3.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: presenter.currentPage)
                .onChange(of: presenter.currentPage) { _, newValue in
                    presenter.onPageChanged(newValue)
                }

                pageIndicator
                    .padding(.bottom, 24)

                bottomButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
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

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.25), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: pageOrbOffset.x, y: -280)
                .blur(radius: 60)
                .animation(.easeInOut(duration: 0.6), value: presenter.currentPage)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .offset(x: -pageOrbOffset.x, y: -100)
                .blur(radius: 50)
                .animation(.easeInOut(duration: 0.6), value: presenter.currentPage)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.indigo.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .offset(x: 40, y: 200)
                .blur(radius: 40)
        }
    }

    private var pageOrbOffset: CGPoint {
        switch presenter.currentPage {
        case 0:  return CGPoint(x: -80, y: 0)
        case 1:  return CGPoint(x: 60, y: 0)
        case 2:  return CGPoint(x: -20, y: 0)
        default: return CGPoint(x: -20, y: 0)
        }
    }

    // MARK: - Page 1: AI-Powered Creation

    private var page1: some View {
        OnboardingPageView(
            illustration: AnyView(page1Illustration),
            title: String(localized: "Create with Intelligence"),
            subtitle: String(localized: "Generate flashcards instantly from any text using on-device AI. Just paste your notes or upload a PDF and let Keyoku do the rest.")
        )
    }

    private var page1Illustration: some View {
        ZStack {
            // Source text card (back)
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(.systemGray5), Color(.systemGray6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 110)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 100, height: 5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 80, height: 5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 110, height: 5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 60, height: 5)
                    }
                    .padding(16)
                }
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                .rotationEffect(.degrees(-6))
                .offset(x: -40, y: 20)

            // Sparkle connector
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(x: 0, y: -10)

            // Generated flashcard (front)
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 110)
                .overlay {
                    VStack(spacing: 8) {
                        Text("Q")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.6))

                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.4))
                            .frame(width: 90, height: 5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.3))
                            .frame(width: 70, height: 5)
                    }
                }
                .shadow(color: Color.accentColor.opacity(0.25), radius: 16, y: 8)
                .rotationEffect(.degrees(4))
                .offset(x: 44, y: -16)
        }
    }

    // MARK: - Page 2: Organize Decks

    private var page2: some View {
        OnboardingPageView(
            illustration: AnyView(page2Illustration),
            title: String(localized: "Organize Your Knowledge"),
            subtitle: String(localized: "Create colorful decks of flashcards. Keep your subjects tidy and find what you need at a glance.")
        )
    }

    private var page2Illustration: some View {
        ZStack {
            deckMiniCard(color: .green, rotation: -10, offset: CGSize(width: -60, height: 16))
            deckMiniCard(color: .orange, rotation: 8, offset: CGSize(width: 56, height: 12))
            deckMiniCard(color: .purple, rotation: -3, offset: CGSize(width: -16, height: -20))

            // Center primary deck
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [.accentColor, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 105)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                        Text("Biology")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        Text("24 cards")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(14)
                }
                .shadow(color: Color.accentColor.opacity(0.3), radius: 16, y: 8)
                .offset(x: 8, y: -4)
        }
    }

    private func deckMiniCard(color: Color, rotation: Double, offset: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 120, height: 85)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.4))
                        .frame(width: 50, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.25))
                        .frame(width: 30, height: 4)
                }
                .padding(12)
            }
            .shadow(color: color.opacity(0.2), radius: 10, y: 4)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
    }

    // MARK: - Page 3: Study Your Way

    private var page3: some View {
        OnboardingPageView(
            illustration: AnyView(page3Illustration),
            title: String(localized: "Study Your Way"),
            subtitle: String(localized: "Flip through flashcards to practice and reinforce what you've learned. Study at your own pace.")
        )
    }

    private var page3Illustration: some View {
        HStack(spacing: 16) {
            // Flashcard side
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 160)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))

                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.4))
                                    .frame(width: 80, height: 5)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.3))
                                    .frame(width: 60, height: 5)
                            }

                            Text("Tap to flip")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .shadow(color: Color.accentColor.opacity(0.25), radius: 12, y: 6)

                Text("Flashcards")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            // Back of card
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .purple.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 160)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "lightbulb.fill")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))

                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.4))
                                    .frame(width: 80, height: 5)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.3))
                                    .frame(width: 60, height: 5)
                            }

                            Text("Answer")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .shadow(color: Color.purple.opacity(0.25), radius: 12, y: 6)

                Text("Review")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<OnboardingCompletedPresenter.totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == presenter.currentPage ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: index == presenter.currentPage ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: presenter.currentPage)
            }
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        ZStack {
            if presenter.isCompletingProfileSetup {
                ProgressView()
                    .tint(.white)
            } else {
                Text(presenter.isLastPage ? "Get Started" : "Continue")
            }
        }
        .callToActionButton(cornerRadius: 14)
        .anyButton(.press) {
            if presenter.isLastPage {
                presenter.onFinishButtonPressed()
            } else {
                presenter.onContinuePressed()
            }
        }
        .accessibilityIdentifier("FinishButton")
        .disabled(presenter.isCompletingProfileSetup)
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.onboardingCompletedView(
            router: router,
            delegate: OnboardingCompletedDelegate()
        )
    }
}

extension CoreBuilder {

    func onboardingCompletedView(router: AnyRouter, delegate: OnboardingCompletedDelegate) -> some View {
        OnboardingCompletedView(
            presenter: OnboardingCompletedPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showOnboardingCompletedView(delegate: OnboardingCompletedDelegate) {
        router.showScreen(.push) { router in
            builder.onboardingCompletedView(router: router, delegate: delegate)
        }
    }

}
