import SwiftUI
import SwiftfulUI

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
                welcomeHeader
                recentDecksSection
                recentQuizzesSection
                quickActionsSection
            }
            .padding()
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
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        Text(greeting)
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(presenter.decks.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())

                    Text(presenter.decks.count == 1 ? "deck" : "decks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(presenter.totalCardCount) cards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            Color.accentColor.opacity(0.2),
                            lineWidth: 1
                        )
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(presenter.decks.count) \(presenter.decks.count == 1 ? "deck" : "decks"), \(presenter.totalCardCount) \(presenter.totalCardCount == 1 ? "card" : "cards")")
    }

    // MARK: - Recent Decks Section

    private var recentDecksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Decks")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

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

    // MARK: - Recent Quizzes Section

    private var recentQuizzesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Quizzes")
                .font(.title3)
                .fontWeight(.semibold)

            if presenter.recentQuizzes.isEmpty {
                emptyQuizzesCard
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(presenter.recentQuizzes) { quiz in
                            quizCard(quiz: quiz)
                                .card3DScroll()
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private var emptyQuizzesCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No quizzes yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Create a quiz to test your knowledge")
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

    private func quizCard(quiz: QuizModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(quiz.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "questionmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityHidden(true)
            }

            Spacer()

            Text("\(quiz.questions.count) question\(quiz.questions.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
        .frame(width: deckCardWidth, height: deckCardHeight, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [quiz.color.color, quiz.color.color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .accessibilityLabel("\(quiz.name), \(quiz.questions.count) \(quiz.questions.count == 1 ? "question" : "questions")")
        .accessibilityHint("Opens quiz")
        .anyButton(.press) {
            presenter.onQuizPressed(quiz: quiz)
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.white)

                Text("Create New")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
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
            .accessibilityHint("Create a new deck or quiz")
            .anyButton(.press) {
                presenter.onCreatePressed()
            }
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
