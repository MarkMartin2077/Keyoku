//
//  AppDelegate.swift
//  Keyoku
//
//  
//
import SwiftUI
import Firebase
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    var dependencies: Dependencies!
    var builder: Builder!
    static var pendingQuickAction: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        
        var config: BuildConfiguration
        
        #if MOCK
        config = .mock(isSignedIn: false)
        #elseif DEV
        config = .dev
        #else
        config = .prod
        #endif
        
        if Utilities.isUITesting {
            let isSignedIn = ProcessInfo.processInfo.arguments.contains("SIGNED_IN")
            config = .mock(isSignedIn: isSignedIn)
        }
        
        config.configure()
        
        // Must be called AFTER configuring Firebase
        registerForRemotePushNotifications(application: application)
        
        let dependencies = Dependencies(config: config)
        self.dependencies = dependencies
        self.builder = CoreBuilder(interactor: CoreInteractor(container: dependencies.container))
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            // Cold launch: store for HomePresenter to pick up on appear
            AppDelegate.pendingQuickAction = shortcutItem.type
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        let userInfo: [String: String] = ["action_type": shortcutItem.type]
        NotificationCenter.default.post(name: .quickAction, object: nil, userInfo: userInfo)
    }

    private func registerForRemotePushNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        #if !MOCK
        // Only need to set Firebase Messaging if Firebase is configured
        Messaging.messaging().delegate = self
        #endif
        application.registerForRemoteNotifications()
    }
}

/// Firbase Cloud Messaging Docs: https://firebase.google.com/docs/cloud-messaging/ios/client
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        #if DEBUG
        print("🚨 didFailToRegisterForRemoteNotificationsWithError: \(error.localizedDescription)")
        #endif
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        let notificationId = response.notification.request.identifier

        // Remote (Firebase) notifications store payload under "aps", local notifications use userInfo directly
        var userInfo: [String: Any] = content.userInfo["aps"] as? [String: Any] ?? content.userInfo as? [String: Any] ?? [:]
        userInfo["notification_id"] = notificationId

        NotificationCenter.default.post(name: .pushNotification, object: nil, userInfo: userInfo)
        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
    
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        NotificationCenter.default.postFCMToken(token: fcmToken ?? "")
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.handleQuickAction(shortcutItem)
        completionHandler(true)
    }
}

enum BuildConfiguration {
    case mock(isSignedIn: Bool), dev, prod
    
    func configure() {
        switch self {
        case .mock:
            // Mock build does NOT run Firebase
            break
        case .dev:
            let plist = Bundle.main.path(forResource: "GoogleService-Info-Dev", ofType: "plist")!
            let options = FirebaseOptions(contentsOfFile: plist)!
            FirebaseApp.configure(options: options)
        case .prod:
            let plist = Bundle.main.path(forResource: "GoogleService-Info-Prod", ofType: "plist")!
            let options = FirebaseOptions(contentsOfFile: plist)!
            FirebaseApp.configure(options: options)
        }
    }
}
