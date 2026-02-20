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
        let name = presenter.userName.map { ", \($0)" } ?? ""
        switch hour {
        case 5..<12:
            return "☀️ Good morning\(name)"
        case 12..<17:
            return "🌤️ Good afternoon\(name)"
        default:
            return "🌙 Good evening\(name)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroSection
                recentDecksSection
                if !presenter.decks.isEmpty {
                    continueStudyingSection
                }
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
                .lineLimit(1)
                .minimumScaleFactor(0.6)
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

    // MARK: - Recent Decks Section

    private var recentDecksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Decks")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("View All")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.accent)
                    .accessibilityLabel("View all decks")
                    .anyButton(.press) {
                        presenter.onViewAllDecksPressed()
                    }
            }

            if presenter.recentDecks.isEmpty {
                emptyDecksCard
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(presenter.recentDecks) { deck in
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

    // MARK: - Continue Studying Section

    private var continueStudyingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Studying")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            if presenter.hasStudiedDecks {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(presenter.studiedDecks) { deck in
                        studyCard(deck: deck)
                    }
                }
            } else {
                emptyStudyCard
            }
        }
    }

    private func studyCard(deck: DeckModel) -> some View {
        let learnedCount = deck.flashcards.filter { $0.isLearned }.count
        let totalCount = deck.flashcards.count
        let progress = totalCount > 0 ? Double(learnedCount) / Double(totalCount) : 0

        return HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(deck.color.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(deck.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(learnedCount) / \(totalCount) learned")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(.green)
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(12)
        }
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .anyButton(.press) {
            presenter.onDeckPressed(deck: deck)
        }
    }

    private var emptyStudyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No decks studied yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Practice a deck to track your progress")
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
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [deck.color.color, deck.color.color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let imageUrl = deck.displayImageUrlString {
                    ImageLoaderView(urlString: imageUrl)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: deckCardWidth, height: deckCardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    RoundedRectangle(cornerRadius: 16)
                        .fill(.black.opacity(0.35))
                }
            }
        }
        .accessibilityLabel("\(deck.name), \(deck.flashcards.count) \(deck.flashcards.count == 1 ? "card" : "cards")")
        .accessibilityHint("Opens deck")
        .anyButton(.press) {
            presenter.onDeckPressed(deck: deck)
        }
    }

    // MARK: - Floating Create Button

    private var floatingCreateButton: some View {
        VStack(spacing: 8) {
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

            if !presenter.isPremium {
                Text("\(presenter.decks.count) of \(Constants.freeTierDeckLimit) free decks")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(.bar)
        .accessibilityHint("Create a new deck")
        .anyButton(.press) {
            presenter.onCreatePressed()
        }
        .accessibilityIdentifier("CreateNewButton")
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
            .accessibilityLabel("Developer settings")
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
