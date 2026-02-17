import SwiftUI
import SwiftfulUI
import CoreSpotlight

struct HomeDelegate {
    var eventParameters: [String: Any]? {
        nil
    }
}

struct HomeView: View {

    @State var presenter: HomePresenter
    let delegate: HomeDelegate
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var deckCardWidth: CGFloat { sizeClass == .regular ? 200 : 150 }
    private var deckCardHeight: CGFloat { sizeClass == .regular ? 150 : 120 }

    private var showDevSettingsButton: Bool {
        #if DEV || MOCK
        return true
        #else
        return false
        #endif
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroSection
                yourDecksSection
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            floatingCreateButton
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if showDevSettingsButton {
                    devSettingsButton
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                streakIndicator
            }

            ToolbarItem(placement: .topBarTrailing) {
                if presenter.showNotificationButton {
                    pushNotificationButton
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gear") {
                    presenter.onSettingsPressed()
                }
            }
        }
        .onFirstAppear {
            presenter.onFirstAppear(delegate: delegate)
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .onOpenURL { url in
            presenter.handleDeepLink(url: url)
        }
        .onNotificationRecieved(name: .pushNotification) { notification in
            presenter.handlePushNotificationRecieved(notification: notification)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
            presenter.handleSpotlightActivity(userActivity)
        }
        .onNotificationRecieved(name: .quickAction) { notification in
            presenter.handleQuickAction(notification: notification)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(presenter.currentStreak > 0 ? .orange : .gray)
                    Text("\(presenter.currentStreak) day streak")
                }

                Text("·")
                    .foregroundStyle(.tertiary)

                Text("\(presenter.decks.count) \(presenter.decks.count == 1 ? "deck" : "decks")")

                Text("·")
                    .foregroundStyle(.tertiary)

                Text("\(presenter.totalCardCount) \(presenter.totalCardCount == 1 ? "card" : "cards")")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Your Decks Section

    private var yourDecksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Decks")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("View All")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.accent)
                    .anyButton(.press) {
                        presenter.onViewAllDecksPressed()
                    }
            }

            if presenter.sortedDecks.isEmpty {
                emptyDecksCard
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(presenter.sortedDecks) { deck in
                            deckCard(deck: deck)
                                .card3DScroll()
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private var emptyDecksCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No decks yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Create a deck to start studying")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                }
        }
    }

    private func deckCard(deck: DeckModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(deck.name)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()

            Text("\(deck.flashcards.count) card\(deck.flashcards.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
        .frame(width: deckCardWidth, height: deckCardHeight, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [deck.color.color, deck.color.color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .accessibilityLabel("\(deck.name), \(deck.flashcards.count) \(deck.flashcards.count == 1 ? "card" : "cards")")
        .accessibilityHint("Opens deck")
        .anyButton(.press) {
            presenter.onDeckPressed(deck: deck)
        }
    }

    // MARK: - Floating Create Button

    private var floatingCreateButton: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.headline)

            Text("Create New")
                .font(.headline)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
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
        .padding(.horizontal)
        .padding(.bottom, 12)
        .accessibilityHint("Create a new deck")
        .anyButton(.press) {
            presenter.onCreatePressed()
        }
    }

    // MARK: - Dev Settings

    private var devSettingsButton: some View {
        Text("DEV")
            .foregroundStyle(.white)
            .font(.callout)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.accent)
            .cornerRadius(12)
            .anyButton(.press) {
                presenter.onDevSettingsPressed()
            }
    }
    
    // MARK: - Streak Indicator

    private var streakIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(presenter.currentStreak > 0 ? .orange : .gray)
            Text("\(presenter.currentStreak)")
                .fontWeight(.semibold)
                .contentTransition(.numericText())
        }
        .font(.subheadline)
        .accessibilityLabel("\(presenter.currentStreak) day streak")
    }

    // MARK: - Push Notifications
    private var pushNotificationButton: some View {
        Image(systemName: "bell.fill")
            .font(.headline)
            .padding(4)
            .tappableBackground()
            .foregroundStyle(.accent)
            .accessibilityLabel("Notifications")
            .anyButton {
                presenter.onPushNotificationButtonPressed()
            }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)
    let builder = CoreBuilder(interactor: interactor)
    let delegate = HomeDelegate()

    return RouterView { router in
        builder.homeView(router: router, delegate: delegate)
    }
}

extension CoreBuilder {

    func homeView(router: AnyRouter, delegate: HomeDelegate) -> some View {
        HomeView(
            presenter: HomePresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }

}

extension CoreRouter {

    func showHomeView(delegate: HomeDelegate) {
        router.showScreen(.push) { router in
            builder.homeView(router: router, delegate: delegate)
        }
    }

}
