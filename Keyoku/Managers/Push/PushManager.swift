//
//  PushManager.swift
//  
//
//  
//
import Foundation
import SwiftfulUtilities
import FirebaseMessaging

@MainActor
@Observable
class PushManager {
    
    private let logManager: LogManager?
    
    init(logManager: LogManager? = nil) {
        self.logManager = logManager
    }
    
    func requestAuthorization() async throws -> Bool {
        let isAuthorized = try await LocalNotifications.requestAuthorization()
        logManager?.addUserProperties(dict: ["push_is_authorized": isAuthorized], isHighPriority: true)
        return isAuthorized
    }
    
    func canRequestAuthorization() async -> Bool {
        await LocalNotifications.canRequestAuthorization()
    }
    
    private let notificationHour: Int = 10
    private let notificationMinute: Int = 0

    private struct ScheduledMessage {
        let title: String
        let subtitle: String
        let day: Int
        let action: String
    }

    private let messages: [ScheduledMessage] = [
        .init(title: String(localized: "Hey you! Wanna study?"), subtitle: String(localized: "Open Keyoku to get started."), day: 1, action: "study"),
        .init(title: String(localized: "Time to practice!"), subtitle: String(localized: "Open Keyoku and try your best."), day: 2, action: "study"),
        .init(title: String(localized: "Hey stranger. We miss you!"), subtitle: String(localized: "Don't forget about us."), day: 3, action: "quiz"),
        .init(title: String(localized: "Knowledge awaits!"), subtitle: String(localized: "Your flashcards are waiting for you."), day: 4, action: "study"),
        .init(title: String(localized: "Quick quiz time?"), subtitle: String(localized: "Test what you've learned today."), day: 5, action: "quiz"),
        .init(title: String(localized: "Keep the streak going!"), subtitle: String(localized: "A few minutes of study goes a long way."), day: 6, action: "create"),
        .init(title: String(localized: "Your brain will thank you!"), subtitle: String(localized: "Open Keyoku and learn something new."), day: 7, action: "create")
    ]

    func schedulePushNotificationsForTheNextWeek() {
        Task {
            do {
                let status = try await LocalNotifications.getNotificationStatus()
                guard status == .authorized else { return }

                LocalNotifications.removeAllPendingNotifications()
                LocalNotifications.removeAllDeliveredNotifications()

                for message in messages {
                    guard let triggerDate = notificationDate(daysFromNow: message.day) else { continue }
                    try await scheduleNotification(
                        id: "\(message.action)-day\(message.day)",
                        title: message.title,
                        subtitle: message.subtitle,
                        triggerDate: triggerDate
                    )
                }

                logManager?.trackEvent(event: Event.weekScheduledSuccess)
            } catch {
                logManager?.trackEvent(event: Event.weekScheduledFail(error: error))
            }
        }
    }

    private func notificationDate(daysFromNow: Int) -> Date? {
        let calendar = Calendar.current
        guard let futureDate = calendar.date(byAdding: .day, value: daysFromNow, to: Date()) else { return nil }
        return calendar.date(bySettingHour: notificationHour, minute: notificationMinute, second: 0, of: futureDate)
    }

    private func scheduleNotification(id: String, title: String, subtitle: String, triggerDate: Date) async throws {
        let content = AnyNotificationContent(id: id, title: title, body: subtitle)
        let trigger = NotificationTriggerOption.date(date: triggerDate, repeats: false)
        try await LocalNotifications.scheduleNotification(content: content, trigger: trigger)
    }
    
    enum Event: LoggableEvent {
        case weekScheduledSuccess
        case weekScheduledFail(error: Error)
        case weekScheduledSkippedNotAuthorized

        var eventName: String {
            switch self {
            case .weekScheduledSuccess:                 return "PushMan_WeekSchedule_Success"
            case .weekScheduledFail:                    return "PushMan_WeekSchedule_Fail"
            case .weekScheduledSkippedNotAuthorized:    return "PushMan_WeekSchedule_Skipped_NotAuth"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .weekScheduledFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }
        
        var type: LogType {
            switch self {
            case .weekScheduledFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
