import SwiftUI

@Observable
@MainActor
class HomePresenter {

    private let interactor: HomeInteractor
    private let router: HomeRouter

    // MARK: - Dashboard Data

    var decks: [DeckModel] {
        interactor.decks
    }

    var recentDecks: [DeckModel] {
        Array(
            decks.sorted { $0.createdAt > $1.createdAt }
                .prefix(3)
        )
    }

    var totalCardCount: Int {
        decks.reduce(0) { $0 + $1.flashcards.count }
    }

    var currentStreakData: CurrentStreakData {
        interactor.currentStreakData
    }

    var currentXPData: CurrentExperiencePointsData {
        interactor.currentExperiencePointsData
    }

    init(interactor: HomeInteractor, router: HomeRouter) {
        self.interactor = interactor
        self.router = router
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: HomeDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        interactor.loadDecks()
    }

    func onViewDisappear(delegate: HomeDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    // MARK: - Actions

    func onDeckPressed(deck: DeckModel) {
        interactor.trackEvent(event: Event.onDeckPressed(deck: deck))
        router.showDeckDetailView(deck: deck)
    }

    func onCreateDeckPressed() {
        interactor.trackEvent(event: Event.onCreateDeckPressed)
        router.showCreateDeckView()
    }

    func onViewAllDecksPressed() {
        interactor.trackEvent(event: Event.onViewAllDecksPressed)
        router.showDecksView(delegate: DecksDelegate())
    }

    func handleDeepLink(url: URL) {
        interactor.trackEvent(event: Event.deepLinkStart)

        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems,
            !queryItems.isEmpty else {
            interactor.trackEvent(event: Event.deepLinkNoQueryItems)
            return
        }

        interactor.trackEvent(event: Event.deepLinkSuccess)

        for queryItem in queryItems {
            if let value = queryItem.value, !value.isEmpty {
                // Do something with value
            }
        }
    }

    func handlePushNotificationRecieved(notification: Notification) {
        interactor.trackEvent(event: Event.pushNotifStart)

        guard
            let userInfo = notification.userInfo,
            !userInfo.isEmpty else {
            interactor.trackEvent(event: Event.pushNotifNoData)
            return
        }

        interactor.trackEvent(event: Event.pushNotifSuccess)

        for (_, _) in userInfo {
            // Do something with (key, value)
        }
    }

    func onDevSettingsPressed() {
        #if MOCK || DEV
        interactor.trackEvent(event: Event.onDevSettings)
        router.showDevSettingsView()
        #else
        interactor.trackEvent(event: Event.onDevSettingsFail)
        #endif
    }
}

extension HomePresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: HomeDelegate)
        case onDisappear(delegate: HomeDelegate)
        case onDeckPressed(deck: DeckModel)
        case onCreateDeckPressed
        case onViewAllDecksPressed
        case deepLinkStart
        case deepLinkNoQueryItems
        case deepLinkSuccess
        case pushNotifStart
        case pushNotifNoData
        case pushNotifSuccess
        case onDevSettings
        case onDevSettingsFail

        var eventName: String {
            switch self {
            case .onAppear:                 return "HomeView_Appear"
            case .onDisappear:              return "HomeView_Disappear"
            case .onDeckPressed:            return "HomeView_Deck_Pressed"
            case .onCreateDeckPressed:      return "HomeView_CreateDeck_Pressed"
            case .onViewAllDecksPressed:    return "HomeView_ViewAllDecks_Pressed"
            case .deepLinkStart:            return "HomeView_DeepLink_Start"
            case .deepLinkNoQueryItems:     return "HomeView_DeepLink_NoItems"
            case .deepLinkSuccess:          return "HomeView_DeepLink_Success"
            case .pushNotifStart:           return "HomeView_PushNotif_Start"
            case .pushNotifNoData:          return "HomeView_PushNotif_NoItems"
            case .pushNotifSuccess:         return "HomeView_PushNotif_Success"
            case .onDevSettings:            return "HomeView_DevSettings"
            case .onDevSettingsFail:        return "HomeView_DevSettings_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onDeckPressed(deck: let deck):
                return deck.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .onDevSettingsFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
