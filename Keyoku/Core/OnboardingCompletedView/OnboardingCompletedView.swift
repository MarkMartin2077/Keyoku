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
                    page4.tag(3)
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
        case 3:  return CGPoint(x: 40, y: 0)
        default: return CGPoint(x: 40, y: 0)
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

    // MARK: - Page 2: Smart Reviews

    private var page2: some View {
        OnboardingPageView(
            illustration: AnyView(page2Illustration),
            title: String(localized: "Reviews That Actually Stick"),
            subtitle: String(localized: "Keyoku schedules each card for review at the perfect moment — just before you'd forget it. The more you practice, the smarter it gets.")
        )
    }

    private var page2Illustration: some View {
        ZStack {
            // Far card — long interval
            srsCard(label: "21 days", color: .green, rotation: -12, offset: CGSize(width: -64, height: 28))

            // Middle card — medium interval
            srsCard(label: "6 days", color: .blue, rotation: 10, offset: CGSize(width: 60, height: 24))

            // Front card — due today
            srsCard(label: "Due today", color: .orange, rotation: -2, offset: CGSize(width: 0, height: -10))

            // Clock badge
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 22))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(x: 54, y: -70)
        }
    }

    /// Renders a single mini flashcard for the spaced-repetition illustration on page 2.
    ///
    /// Each card shows placeholder content lines and a colored review-interval badge
    /// (e.g. "Due today", "6 days", "21 days") to illustrate that different cards are
    /// scheduled for review at different times.
    private func srsCard(label: String, color: Color, rotation: Double, offset: CGSize) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(color.opacity(0.1))
            .frame(width: 130, height: 90)
            .overlay {
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.3))
                        .frame(width: 80, height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 4)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(color.opacity(0.15))
                            .overlay {
                                Capsule()
                                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
                            }
                    }
                    .padding(10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(color.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: color.opacity(0.15), radius: 10, y: 4)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
    }

    // MARK: - Page 3: Study Your Way

    private var page3: some View {
        OnboardingPageView(
            illustration: AnyView(page3Illustration),
            title: String(localized: "Study Your Way"),
            subtitle: String(localized: "Swipe right when you know it, left when you need more practice. Keyoku tracks your progress card by card.")
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

    // MARK: - Page 4: Build a Study Habit

    private var page4: some View {
        OnboardingPageView(
            illustration: AnyView(page4Illustration),
            title: String(localized: "Build a Study Habit"),
            subtitle: String(localized: "Complete a study session each day to build your streak. Stay consistent and watch your flame grow!")
        )
    }

    private var page4Illustration: some View {
        ZStack {
            // Glow behind flame
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.orange.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)

            // Flame icon
            Image(systemName: "flame.fill")
                .font(.system(size: 90))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .orange.opacity(0.4), radius: 20, y: 8)

            // Streak badge
            VStack(spacing: 2) {
                Text("7")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("days")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
            }
            .offset(x: 60, y: 50)

            // Mini calendar dots showing consistency
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(index < 5 ? Color.orange : Color.secondary.opacity(0.2))
                        .frame(width: 10, height: 10)
                }
            }
            .offset(y: 100)
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
