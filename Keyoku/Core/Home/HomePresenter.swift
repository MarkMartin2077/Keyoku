import SwiftUI

@Observable
@MainActor
class HomePresenter {

    private let interactor: HomeInteractor
    private let router: HomeRouter

    private(set) var showNotificationButton: Bool = false
    
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

    var quizzes: [QuizModel] {
        interactor.quizzes
    }

    var recentQuizzes: [QuizModel] {
        Array(
            quizzes.sorted { $0.createdAt > $1.createdAt }
                .prefix(3)
        )
    }

    var totalQuestionCount: Int {
        quizzes.reduce(0) { $0 + $1.questions.count }
    }

    init(interactor: HomeInteractor, router: HomeRouter) {
        self.interactor = interactor
        self.router = router
    }

    // MARK: - Lifecycle

    func onViewAppear(delegate: HomeDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        interactor.loadDecks()
        interactor.loadQuizzes()

        Task {
            await checkShowPushNotificationButton()
        }

        schedulePushNotifications()
    }

    func onViewDisappear(delegate: HomeDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    // MARK: - Actions

    func onDeckPressed(deck: DeckModel) {
        interactor.trackEvent(event: Event.onDeckPressed(deck: deck))
        router.showDeckDetailView(deck: deck)
    }

    func onCreatePressed() {
        interactor.trackEvent(event: Event.onCreatePressed)
        router.showCreateContentView(defaultContentType: nil)
    }

    func onQuizPressed(quiz: QuizModel) {
        interactor.trackEvent(event: Event.onQuizPressed(quiz: quiz))
        router.showQuizView(quiz: quiz)
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
        case "quiz":
            if let id = params["id"], let quiz = interactor.getQuiz(id: id) {
                router.showQuizView(quiz: quiz)
            }
        case "create":
            let contentType = deepLinkContentType(from: params["type"])
            router.showCreateContentView(defaultContentType: contentType)
        default:
            break
        }
    }

    private func deepLinkContentType(from value: String?) -> CreateDeckPresenter.ContentType? {
        switch value {
        case "flashcards": return .flashcards
        case "quiz": return .quiz
        case "both": return .both
        default: return nil
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
            if let deck = recentDecks.first {
                router.showDeckDetailView(deck: deck)
            }
        } else if id.hasPrefix("quiz") {
            if let quiz = recentQuizzes.first {
                router.showQuizView(quiz: quiz)
            }
        } else if id.hasPrefix("create") {
            router.showCreateContentView(defaultContentType: nil)
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
    
    func onSettingsPressed() {
        router.showSettingsView()
    }
}

extension HomePresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: HomeDelegate)
        case onDisappear(delegate: HomeDelegate)
        case onDeckPressed(deck: DeckModel)
        case onQuizPressed(quiz: QuizModel)
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

        var eventName: String {
            switch self {
            case .onAppear:                 return "HomeView_Appear"
            case .onDisappear:              return "HomeView_Disappear"
            case .onDeckPressed:            return "HomeView_Deck_Pressed"
            case .onQuizPressed:            return "HomeView_Quiz_Pressed"
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
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .onDeckPressed(deck: let deck):
                return deck.eventParameters
            case .onQuizPressed(quiz: let quiz):
                return quiz.eventParameters
            case .pushNotifsEnable(isAuthorized: let isAuthorized):
                return ["is_authorized": isAuthorized]
            case .pushNotifAction(notificationId: let notificationId):
                return ["notification_id": notificationId]
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
