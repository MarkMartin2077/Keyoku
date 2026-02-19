//
//  Constants.swift
//  Keyoku
//
//  
//
struct Constants {
    static let randomImage = "https://picsum.photos/600/600"
    static let privacyPolicyUrlString = "https://boatneck-pickle-bfa.notion.site/Privacy-Policy-4c140d62f69d406eb2906db09dad1781"
    static let termsOfServiceUrlString = "https://boatneck-pickle-bfa.notion.site/Terms-of-Service-ef9a22b727d74a07afd8a50a7b3e8e6c"
    
    static let onboardingModuleId = "onboarding"
    static let tabbarModuleId = "tabbar"
    
    static let streakKey = "daily" // daily streaks
    static let xpKey = "general" // general XP
    static let progressKey = "general" // general progress

    static var mixpanelDistinctId: String? {
        #if MOCK
        return nil
        #else
        return MixpanelService.distinctId
        #endif
    }
    
    static var firebaseAnalyticsAppInstanceID: String? {
        #if MOCK
        return nil
        #else
        return FirebaseAnalyticsService.appInstanceID
        #endif
    }

    @MainActor
    static var firebaseAppClientId: String? {
        #if MOCK
        return nil
        #else
        return FirebaseAuthService.clientId
        #endif
    }

}
