import SwiftUI
import CoreSpotlight

/// Main dashboard presenter that serves as the primary entry point after authentication.
///
/// Manages deck display (recent, studied, sorted), deck creation with free-tier limit enforcement,
/// and a first-deck premium prompt. Also handles deep links, push notifications, Spotlight indexing,
/// and quick actions — all of which route to the appropriate screen.
@Observable
@MainActor
class HomePresenter {

    private let interactor: HomeInteractor
    private let router: HomeRouter

    private(set) var showNotificationButton: Bool = false
    
    // MARK: - User Data

    var userName: String? {
        interactor.currentUser?.firstNameCalculated
    }

    // MARK: - Streak Data

    var currentStreak: Int {
        interactor.currentStreakData.currentStreak ?? 0
    }

    // MARK: - Dashboard Data

    var decks: [DeckModel] {
        interactor.decks
    }

    var recentDecks: [DeckModel] {
        decks.sorted {
            if $0.clickCount != $1.clickCount {
                return $0.clickCount > $1.clickCount
            }
            return $0.createdAt > $1.createdAt
        }
    }

    var studiedDecks: [DeckModel] {
        decks
            .filter { deck in
                deck.clickCount > 0 && deck.flashcards.contains(where: { !$0.isLearned })
            }
            .sorted { lhs, rhs in
                let lhsUnlearned = lhs.flashcards.filter { !$0.isLearned }.count
                let rhsUnlearned = rhs.flashcards.filter { !$0.isLearned }.count
                return lhsUnlearned > rhsUnlearned
            }
    }

    var hasStudiedDecks: Bool {
        !studiedDecks.isEmpty
    }

    var sortedDecks: [DeckModel] {
        decks.sorted { $0.createdAt > $1.createdAt }
    }

    var totalCardCount: Int {
        decks.reduce(0) { $0 + $1.flashcards.count }
    }

    var canCreateDeck: Bool {
        interactor.isPremium || decks.count < Constants.freeTierDeckLimit
    }

    init(interactor: HomeInteractor, router: HomeRouter) {
        self.interactor = interactor
        self.router = router
    }

    // MARK: - Lifecycle

    func onFirstAppear(delegate: HomeDelegate) {
        interactor.loadDecks()

        Task {
            await checkShowPushNotificationButton()
        }

        schedulePushNotifications()
        checkPendingQuickAction()
    }

    func onViewAppear(delegate: HomeDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    private func checkPendingQuickAction() {
        guard let actionType = AppDelegate.pendingQuickAction else { return }
        AppDelegate.pendingQuickAction = nil

        interactor.trackEvent(event: Event.quickActionOpen(actionType: actionType))

        switch actionType {
        case "com.keyoku.create":
            guard canCreateDeck else {
                interactor.trackEvent(event: Event.onCreateDeckLimitHit)
                router.showPaywallView(delegate: PaywallDelegate(source: "home_deck_limit"))
                return
            }
            showCreateDeckWithPaywallCheck()
        default:
            break
        }
    }

    func onViewDisappear(delegate: HomeDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    // MARK: - Actions

    func onDeckPressed(deck: DeckModel) {
        interactor.trackEvent(event: Event.onDeckPressed(deck: deck))

        if let latest = interactor.getDeck(id: deck.deckId) {
            let updated = DeckModel(
                deckId: latest.deckId,
                name: latest.name,
                color: latest.color,
                imageUrl: latest.imageUrl,
                sourceText: latest.sourceText,
                createdAt: latest.createdAt,
                flashcards: latest.flashcards,
                clickCount: latest.clickCount + 1
            )
            try? interactor.updateDeck(updated)
        }

        router.showDeckDetailView(deck: deck)
    }

    func onCreatePressed() {
        interactor.trackEvent(event: Event.onCreatePressed)

        guard canCreateDeck else {
            interactor.trackEvent(event: Event.onCreateDeckLimitHit)
            router.showPaywallView(delegate: PaywallDelegate(source: "home_deck_limit"))
            return
        }

        showCreateDeckWithPaywallCheck()
    }

    private func showCreateDeckWithPaywallCheck() {
        let hadCreatedFirstDeck = interactor.currentUser?.didCreateFirstDeck == true
        let wasPremium = interactor.isPremium
        let deckCountBefore = interactor.decks.count

        router.showCreateContentView(onDismiss: { [weak self] in
            guard let self else { return }
            guard !hadCreatedFirstDeck,
                  !wasPremium,
                  interactor.decks.count > deckCountBefore else { return }

            interactor.trackEvent(event: Event.firstDeckPaywallShown)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.6))
                self?.showFirstDeckPremiumPrompt()
            }
        })
    }

    private func showFirstDeckPremiumPrompt() {
        router.showFirstDeckPremiumPromptModal(
            onSeeOfferPressed: { [weak self] in
                self?.router.dismissModal()
                self?.interactor.trackEvent(event: Event.firstDeckPaywallAccepted)
                self?.router.showPaywallView(delegate: PaywallDelegate(source: "first_deck_created"))
            },
            onDismissPressed: { [weak self] in
                self?.router.dismissModal()
                self?.interactor.trackEvent(event: Event.firstDeckPaywallDismissed)
            }
        )
    }

    func onViewAllDecksPressed() {
        interactor.trackEvent(event: Event.onViewAllDecksPressed)
        router.showDecksView(delegate: DecksDelegate())
    }

    func handleDeepLink(url: URL) {
        interactor.trackEvent(event: Event.deepLinkStart)

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            interactor.trackEvent(event: Event.deepLinkNoQueryItems)
            return
        }

        let queryItems = components.queryItems ?? []
        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })

        interactor.trackEvent(event: Event.deepLinkSuccess)
        routeDeepLink(host: components.host, params: params)
    }

    private func routeDeepLink(host: String?, params: [String: String]) {
        switch host {
        case "deck":
            if let id = params["id"], let deck = interactor.getDeck(id: id) {
                router.showDeckDetailView(deck: deck)
            }
        case "create":
            guard canCreateDeck else {
                interactor.trackEvent(event: Event.onCreateDeckLimitHit)
                router.showPaywallView(delegate: PaywallDelegate(source: "home_deck_limit"))
                return
            }
            showCreateDeckWithPaywallCheck()
        default:
            break
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

        if let notificationId = userInfo["notification_id"] as? String {
            handleNotificationAction(id: notificationId)
        }
    }

    private func handleNotificationAction(id: String) {
        interactor.trackEvent(event: Event.pushNotifAction(notificationId: id))

        if id.hasPrefix("study") {
            if let deck = sortedDecks.first {
                router.showDeckDetailView(deck: deck)
            }
        } else if id.hasPrefix("create") {
            showCreateDeckWithPaywallCheck()
        }
    }
    
    func schedulePushNotifications() {
        interactor.schedulePushNotificationsForTheNextWeek()
    }
    
    func onPushNotificationButtonPressed() {
        func onEnablePushNotificationsPressed() {
            router.dismissModal()
            
            Task {
                let isAuthorized = try await interactor.requestPushAuthorization()
                interactor.trackEvent(event: Event.pushNotifsEnable(isAuthorized: isAuthorized))
                await checkShowPushNotificationButton()

                if isAuthorized {
                    schedulePushNotifications()
                }
            }
        }
        
        func onCancelPushNotificationsPressed() {
            router.dismissModal()
            interactor.trackEvent(event: Event.pushNotifsCancel)
        }
        
        interactor.trackEvent(event: Event.pushNotifsStart)
        router.showPushNotificationModal(
                onEnablePressed: {
                    onEnablePushNotificationsPressed()
                },
                onCancelPressed: {
                    onCancelPushNotificationsPressed()
                }
            )
    }

    func checkShowPushNotificationButton() async {
        let canRequest = await interactor.canRequestPushAuthorization()
        showNotificationButton = canRequest
    }

    func onDevSettingsPressed() {
        #if MOCK || DEV
        interactor.trackEvent(event: Event.onDevSettings)
        router.showDevSettingsView()
        #else
        interactor.trackEvent(event: Event.onDevSettingsFail)
        #endif
    }
    
    // MARK: - Spotlight

    func handleSpotlightActivity(_ userActivity: NSUserActivity) {
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            interactor.trackEvent(event: Event.spotlightOpenFail)
            return
        }

        guard let parsed = interactor.parseSpotlightIdentifier(identifier) else {
            interactor.trackEvent(event: Event.spotlightOpenFail)
            return
        }

        interactor.trackEvent(event: Event.spotlightOpen(type: parsed.type, id: parsed.id))
        routeDeepLink(host: parsed.type, params: ["id": parsed.id])
    }

    // MARK: - Quick Actions

    func handleQuickAction(notification: Notification) {
        guard let actionType = notification.userInfo?["action_type"] as? String else {
            interactor.trackEvent(event: Event.quickActionFail)
            return
        }

        interactor.trackEvent(event: Event.quickActionOpen(actionType: actionType))

        switch actionType {
        case "com.keyoku.create":
            guard canCreateDeck else {
                interactor.trackEvent(event: Event.onCreateDeckLimitHit)
                router.showPaywallView(delegate: PaywallDelegate(source: "home_deck_limit"))
                return
            }
            showCreateDeckWithPaywallCheck()
        default:
            break
        }
    }
}

extension HomePresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: HomeDelegate)
        case onDisappear(delegate: HomeDelegate)
        case onDeckPressed(deck: DeckModel)
        case onCreatePressed
        case onViewAllDecksPressed
        case deepLinkStart
        case deepLinkNoQueryItems
        case deepLinkSuccess
        case pushNotifStart
        case pushNotifNoData
        case pushNotifSuccess
        case pushNotifAction(notificationId: String)
        case onDevSettings
        case onDevSettingsFail
        case pushNotifsStart
        case pushNotifsEnable(isAuthorized: Bool)
        case pushNotifsCancel
        case spotlightOpen(type: String, id: String)
        case spotlightOpenFail
        case quickActionOpen(actionType: String)
        case quickActionFail
        case onCreateDeckLimitHit
        case firstDeckPaywallShown
        case firstDeckPaywallAccepted
        case firstDeckPaywallDismissed

        var eventName: String {
            switch self {
            case .onAppear:                 return "HomeView_Appear"
            case .onDisappear:              return "HomeView_Disappear"
            case .onDeckPressed:            return "HomeView_Deck_Pressed"
            case .onCreatePressed:          return "HomeView_Create_Pressed"
            case .onViewAllDecksPressed:    return "HomeView_ViewAllDecks_Pressed"
            case .deepLinkStart:            return "HomeView_DeepLink_Start"
            case .deepLinkNoQueryItems:     return "HomeView_DeepLink_NoItems"
            case .deepLinkSuccess:          return "HomeView_DeepLink_Success"
            case .pushNotifStart:           return "HomeView_PushNotif_Start"
            case .pushNotifNoData:          return "HomeView_PushNotif_NoItems"
            case .pushNotifSuccess:         return "HomeView_PushNotif_Success"
            case .pushNotifAction:          return "HomeView_PushNotif_Action"
            case .onDevSettings:            return "HomeView_DevSettings"
            case .onDevSettingsFail:        return "HomeView_DevSettings_Fail"
            case .pushNotifsStart:          return "HomeView_PushNotifs_Start"
            case .pushNotifsEnable:         return "HomeView_PushNotifs_Enable"
            case .pushNotifsCancel:         return "HomeView_PushNotifs_Cancel"
            case .spotlightOpen:            return "HomeView_Spotlight_Open"
            case .spotlightOpenFail:        return "HomeView_Spotlight_Open_Fail"
            case .quickActionOpen:          return "HomeView_QuickAction_Open"
            case .quickActionFail:          return "HomeView_QuickAction_Fail"
            case .onCreateDeckLimitHit:     return "HomeView_DeckLimit_Hit"
            case .firstDeckPaywallShown:     return "HomeView_FirstDeck_Paywall_Shown"
            case .firstDeckPaywallAccepted:  return "HomeView_FirstDeck_Paywall_Accepted"
            case .firstDeckPaywallDismissed: return "HomeView_FirstDeck_Paywall_Dismissed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onDeckPressed(deck: let deck):
                return deck.eventParameters
            case .pushNotifsEnable(isAuthorized: let isAuthorized):
                return ["is_authorized": isAuthorized]
            case .pushNotifAction(notificationId: let notificationId):
                return ["notification_id": notificationId]
            case .spotlightOpen(type: let type, id: let id):
                return ["spotlight_type": type, "spotlight_id": id]
            case .quickActionOpen(actionType: let actionType):
                return ["action_type": actionType]
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
