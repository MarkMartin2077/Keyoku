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

    private var greeting: String? {
        guard let name = presenter.userName else { return nil }
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning, \(name)"
        case 12..<17:
            return "Good afternoon, \(name)"
        default:
            return "Good evening, \(name)"
        }
    }

    var body: some View {
        Group {
            if presenter.decks.isEmpty {
                emptyStateView
            } else {
                populatedScrollView
            }
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
                Button("New Deck", systemImage: "plus") {
                    presenter.onCreatePressed()
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel("Create new deck")
                .accessibilityIdentifier("CreateNewButton")
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

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 0) {
            if let greeting {
                Text(greeting)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            Spacer()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 96, height: 96)

                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(.accent)
                }

                VStack(spacing: 8) {
                    Text("Create your first deck")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Paste any text and Keyoku will generate flashcards for you instantly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Button {
                    presenter.onCreatePressed()
                } label: {
                    Text("Create Deck")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
                .accessibilityIdentifier("CreateNewButton")
            }
            .padding(.horizontal)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Populated View

    private var populatedScrollView: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroSection
                recentDecksSection
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
            .padding()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let greeting {
                Text(greeting)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Text("\(presenter.decks.count) \(presenter.decks.count == 1 ? "deck" : "decks")")

                Text("·")
                    .foregroundStyle(.tertiary)

                Text("\(presenter.totalCardCount) \(presenter.totalCardCount == 1 ? "card" : "cards")")

                if presenter.currentStreak > 0 {
                    Text("·")
                        .foregroundStyle(.tertiary)

                    streakIndicator
                }
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
