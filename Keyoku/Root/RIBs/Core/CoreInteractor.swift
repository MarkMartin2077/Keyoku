import SwiftUI

@MainActor
struct CoreInteractor: GlobalInteractor {
    private let appState: AppState
    private let authManager: AuthManager
    private let userManager: UserManager
    private let logManager: LogManager
    private let abTestManager: ABTestManager
    private let purchaseManager: PurchaseManager
    private let pushManager: PushManager
    private let hapticManager: HapticManager
    private let soundEffectManager: SoundEffectManager
    private let flashcardManager: FlashcardManager
    private let spotlightManager: SpotlightManager

    init(container: DependencyContainer) {
        self.appState = container.resolve(AppState.self)!
        self.authManager = container.resolve(AuthManager.self)!
        self.userManager = container.resolve(UserManager.self)!
        self.logManager = container.resolve(LogManager.self)!
        self.abTestManager = container.resolve(ABTestManager.self)!
        self.purchaseManager = container.resolve(PurchaseManager.self)!
        self.pushManager = container.resolve(PushManager.self)!
        self.hapticManager = container.resolve(HapticManager.self)!
        self.soundEffectManager = container.resolve(SoundEffectManager.self)!
        self.flashcardManager = container.resolve(FlashcardManager.self)!
        self.spotlightManager = container.resolve(SpotlightManager.self)!
    }
    
    // MARK: APP STATE
    
    var startingModuleId: String {
        appState.startingModuleId
    }

    // MARK: AuthManager
    
    var auth: UserAuthInfo? {
        authManager.auth
    }
    
    func getAuthId() throws -> String {
        try authManager.getAuthId()
    }
    
    func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        try await authManager.signInAnonymously()
    }

    func signInApple() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        try await authManager.signInApple()
    }
    
    func signInGoogle() async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        guard let clientId = Constants.firebaseAppClientId else {
            throw AppError("Firebase not configured or clientID missing")
        }
        return try await authManager.signInGoogle(GIDClientID: clientId)
    }
    
    // MARK: UserManager
    
    var currentUser: UserModel? {
        userManager.currentUser
    }
    
    func getUser(userId: String) async throws -> UserModel {
        try await userManager.getUser(userId: userId)
    }
    
    func saveOnboardingComplete() async throws {
        try await userManager.saveOnboardingCompleteForCurrentUser()
    }
    
    func saveUserName(name: String) async throws {
        try await userManager.saveUserName(name: name)
    }
    
    func saveUserEmail(email: String) async throws {
        try await userManager.saveUserEmail(email: email)
    }
    
    func saveUserProfileImage(image: UIImage) async throws {
        try await userManager.saveUserProfileImage(image: image)
    }
    
    func saveUserFCMToken(token: String) async throws {
        try await userManager.saveUserFCMToken(token: token)
    }

    // MARK: LogManager
    
    func identifyUser(userId: String, name: String?, email: String?) {
        logManager.identifyUser(userId: userId, name: name, email: email)
    }
    
    func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        logManager.addUserProperties(dict: dict, isHighPriority: isHighPriority)
    }
    
    func deleteUserProfile() {
        logManager.deleteUserProfile()
    }
    
    func trackEvent(eventName: String, parameters: [String: Any]? = nil, type: LogType = .analytic) {
        logManager.trackEvent(eventName: eventName, parameters: parameters, type: type)
    }
    
    func trackEvent(event: AnyLoggableEvent) {
        logManager.trackEvent(event: event)
    }

    func trackEvent(event: LoggableEvent) {
        logManager.trackEvent(event: event)
    }
    
    func trackScreenEvent(event: LoggableEvent) {
        logManager.trackEvent(event: event)
    }

    // MARK: PushManager
    
    func requestPushAuthorization() async throws -> Bool {
        try await pushManager.requestAuthorization()
    }
    
    func canRequestPushAuthorization() async -> Bool {
        await pushManager.canRequestAuthorization()
    }
    
    func schedulePushNotificationsForTheNextWeek() {
        pushManager.schedulePushNotificationsForTheNextWeek()
    }
    
    // MARK: ABTestManager
    
    var activeTests: ActiveABTests {
        abTestManager.activeTests
    }
        
    func override(updateTests: ActiveABTests) throws {
        try abTestManager.override(updateTests: updateTests)
    }
    
    // MARK: PurchaseManager
    
    var entitlements: [PurchasedEntitlement] {
        purchaseManager.entitlements
    }
    
    var isPremium: Bool {
        entitlements.hasActiveEntitlement
    }
    
    func getProducts(productIds: [String]) async throws -> [AnyProduct] {
        try await purchaseManager.getProducts(productIds: productIds)
    }
    
    func restorePurchase() async throws -> [PurchasedEntitlement] {
        try await purchaseManager.restorePurchase()
    }
    
    func purchaseProduct(productId: String) async throws -> [PurchasedEntitlement] {
        try await purchaseManager.purchaseProduct(productId: productId)
    }
    
    func updateProfileAttributes(attributes: PurchaseProfileAttributes) async throws {
        try await purchaseManager.updateProfileAttributes(attributes: attributes)
    }
    
    // MARK: Haptics
    
    func prepareHaptic(option: HapticOption) {
        hapticManager.prepare(option: option)
    }
    
    func prepareHaptics(options: [HapticOption]) {
        hapticManager.prepare(options: options)
    }
        
    func playHaptic(option: HapticOption) {
        hapticManager.play(option: option)
    }
    
    func playHaptics(options: [HapticOption]) {
        hapticManager.play(options: options)
    }
    
    func tearDownHaptic(option: HapticOption) {
        hapticManager.tearDown(option: option)
    }
    
    func tearDownHaptics(options: [HapticOption]) {
        hapticManager.tearDown(options: options)
    }
    
    func tearDownAllHaptics() {
        hapticManager.tearDownAll()
    }
    
    // MARK: Sound Effects

    func prepareSoundEffect(sound: SoundEffectFile, simultaneousPlayers: Int = 1) {
        Task {
            await soundEffectManager.prepare(url: sound.url, simultaneousPlayers: simultaneousPlayers, volume: 1)
        }
    }

    func tearDownSoundEffect(sound: SoundEffectFile) {
        Task {
            await soundEffectManager.tearDown(url: sound.url)
        }
    }

    func playSoundEffect(sound: SoundEffectFile) {
        Task {
            await soundEffectManager.play(url: sound.url)
        }
    }

    // MARK: FlashcardManager

    var decks: [DeckModel] {
        flashcardManager.decks
    }

    func loadDecks() {
        flashcardManager.loadDecks()
    }

    func getDeck(id: String) -> DeckModel? {
        flashcardManager.getDeck(id: id)
    }

    func createDeck(name: String, color: DeckColor = .blue, imageUrl: String? = nil, sourceText: String) throws {
        try flashcardManager.createDeck(name: name, color: color, imageUrl: imageUrl, sourceText: sourceText)
        if let deck = flashcardManager.decks.first(where: { $0.name == name }) {
            spotlightManager.indexDeck(deck)
        }
    }

    func createDeck(name: String, color: DeckColor = .blue, imageUrl: String? = nil, sourceText: String, flashcards: [FlashcardModel]) throws {
        try flashcardManager.createDeck(name: name, color: color, imageUrl: imageUrl, sourceText: sourceText, flashcards: flashcards)
        if let deck = flashcardManager.decks.first(where: { $0.name == name }) {
            spotlightManager.indexDeck(deck)
        }
    }

    func updateDeck(_ deck: DeckModel) throws {
        try flashcardManager.updateDeck(deck)
        spotlightManager.indexDeck(deck)
    }

    func deleteDeck(id: String) throws {
        try flashcardManager.deleteDeck(id: id)
        spotlightManager.removeDeck(id: id)
    }

    func addFlashcard(question: String, answer: String, toDeckId: String) throws {
        try flashcardManager.addFlashcard(question: question, answer: answer, toDeckId: toDeckId)
    }

    func deleteFlashcard(id: String, fromDeckId: String) throws {
        try flashcardManager.deleteFlashcard(id: id, fromDeckId: fromDeckId)
    }

    func saveDeckImage(data: Data) throws -> String {
        try flashcardManager.saveDeckImage(data: data)
    }

    // MARK: SpotlightManager

    func parseSpotlightIdentifier(_ identifier: String) -> (type: String, id: String)? {
        spotlightManager.parseSpotlightIdentifier(identifier)
    }

    // MARK: SHARED

    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws {
        // Run all logins in parallel
        async let userLogin: Void = userManager.logIn(auth: user, isNewUser: isNewUser)
        async let purchaseLogin: ([PurchasedEntitlement]) = purchaseManager.logIn(
            userId: user.uid,
            userAttributes: PurchaseProfileAttributes(
                email: user.email,
                mixpanelDistinctId: Constants.mixpanelDistinctId,
                firebaseAppInstanceId: Constants.firebaseAnalyticsAppInstanceID
            )
        )
        async let flashcardLogin: Void = flashcardManager.logIn(userId: user.uid)

        let (_, _, _) = await (try userLogin, try purchaseLogin, try flashcardLogin)

        // Add user properties
        logManager.addUserProperties(dict: Utilities.eventParameters, isHighPriority: false)

        // Index all content for Spotlight search
        spotlightManager.indexAllContent(decks: flashcardManager.decks)
    }

    func signOut() async throws {
        try authManager.signOut()
        try await purchaseManager.logOut()
        userManager.signOut()
        flashcardManager.signOut()
        spotlightManager.removeAllItems()
    }
    
    func deleteAccount() async throws {
        guard let auth else {
            throw AppError("Auth not found.")
        }
        
        var option: SignInOption = .anonymous
        if auth.authProviders.contains(.apple) {
            option = .apple
        } else if auth.authProviders.contains(.google), let clientId = Constants.firebaseAppClientId {
            option = .google(GIDClientID: clientId)
        }
        
        // Delete auth
        try await authManager.deleteAccountWithReauthentication(option: option, revokeToken: false) {
            // Delete User profile (Firestore)
            // Note: this must be done within this closure
            // So that it completes before auth is revoked
            // Once auth is revoked, security rules may restrict user from reading/writing to Firestore
            try await userManager.deleteCurrentUser()
        }
        
        // Delete Purchases (RevenueCat)
        try await purchaseManager.logOut()
        
        // Delete logs (Mixpanel)
        logManager.deleteUserProfile()
    }
}
