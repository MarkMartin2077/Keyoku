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
            return "Good morning\(name)"
        case 12..<17:
            return "Good afternoon\(name)"
        default:
            return "Good evening\(name)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroSection
                recentDecksSection
                if !presenter.decks.isEmpty {
                    if presenter.useCompactPracticeLayout {
                        if presenter.hasDueDecks || presenter.hasStillLearningCards {
                            HomePracticeCompactSectionView(
                                dueCount: presenter.totalDueCardCount,
                                hasDue: presenter.hasDueDecks,
                                stillLearningCount: presenter.stillLearningTotalCount,
                                hasStillLearning: presenter.hasStillLearningCards,
                                onDueTapped: { presenter.onReviewDuePressed() },
                                onStillLearningTapped: { presenter.onStillLearningPressed() }
                            )
                        }
                    } else {
                        if presenter.hasDueDecks {
                            HomeReviewDueSectionView(
                                decks: presenter.dueDecks,
                                onDeckPressed: { presenter.onDueForReviewDeckPressed(deck: $0) },
                                onInfoPressed: { presenter.onReviewDueInfoPressed() }
                            )
                        }
                        if presenter.hasStillLearningCards {
                            HomeStillLearningSectionView(
                                cardCount: presenter.stillLearningTotalCount,
                                deckCount: presenter.stillLearningDeckCount,
                                onPressed: { presenter.onStillLearningPressed() },
                                onInfoPressed: { presenter.onStillLearningInfoPressed() }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if showDevSettingsButton {
                    devSettingsButton
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presenter.onCreatePressed()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create new deck")
                .accessibilityIdentifier("CreateNewButton")
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
            HStack(alignment: .top) {
                Text(greeting)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                streakIndicator
            }

            HStack(spacing: 12) {
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

            Text("Your first deck is one tap away")
                .font(.headline)
                .foregroundStyle(.secondary)
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
        .accessibilityLabel("Create your first deck")
        .accessibilityHint("Tap to create a new deck")
        .anyButton(.press) {
            presenter.onCreatePressed()
        }
    }

    private func deckCard(deck: DeckModel) -> some View {
        let dueCount = deck.flashcards.filter { card in
            guard let dueDate = card.dueDate else { return false }
            return dueDate <= Date()
        }.count

        return VStack(alignment: .leading, spacing: 8) {
            Text(deck.name)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()

            HStack(spacing: 6) {
                Text("\(deck.flashcards.count) card\(deck.flashcards.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))

                if dueCount > 0 {
                    Text("\(dueCount) due")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.2), in: Capsule())
                }
            }
        }
        .padding()
        .frame(width: deckCardWidth, height: deckCardHeight, alignment: .topLeading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(deck.color.color)

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

    func showCrossDeckPracticeView(cards: [FlashcardModel], decks: [DeckModel]) {
        let delegate = PracticeDelegate(crossDeckCards: cards, crossDeckSource: decks)
        router.showScreen(.sheet) { router in
            builder.crossDeckPracticeView(router: router, delegate: delegate)
        }
    }

}
