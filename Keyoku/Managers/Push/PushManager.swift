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

    // MARK: - Reminder Preferences (UserDefaults-backed)

    var reminderHour: Int {
        get {
            guard let saved = UserDefaults.standard.object(forKey: "keyoku_reminder_hour") as? Int else { return 10 }
            return saved
        }
        set { UserDefaults.standard.set(newValue, forKey: "keyoku_reminder_hour") }
    }

    var reminderMinute: Int {
        get { UserDefaults.standard.integer(forKey: "keyoku_reminder_minute") }
        set { UserDefaults.standard.set(newValue, forKey: "keyoku_reminder_minute") }
    }

    var isReminderEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "keyoku_reminder_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "keyoku_reminder_enabled") }
    }

    func setReminderTime(hour: Int, minute: Int) {
        reminderHour = hour
        reminderMinute = minute
        schedulePushNotificationsForTheNextWeek()
    }

    func setReminderEnabled(_ enabled: Bool) async throws {
        isReminderEnabled = enabled
        if enabled {
            schedulePushNotificationsForTheNextWeek()
        } else {
            LocalNotifications.removeAllPendingNotifications()
        }
    }

    // MARK: - Scheduling

    private struct ScheduledMessage {
        let title: String
        let subtitle: String
        let day: Int
        let action: String
    }

    private struct MessageTemplate {
        let title: String
        let subtitle: String
        let action: String
    }

    // Generic fallback pool — used when no card context is available or to fill remaining days.
    private let genericMessages: [MessageTemplate] = [
        MessageTemplate(title: String(localized: "Time to practice!"), subtitle: String(localized: "Open Keyoku and try your best."), action: "study"),
        MessageTemplate(title: String(localized: "Hey, wanna study?"), subtitle: String(localized: "Open Keyoku to get started."), action: "study"),
        MessageTemplate(title: String(localized: "Knowledge awaits!"), subtitle: String(localized: "Your flashcards are waiting for you."), action: "study"),
        MessageTemplate(title: String(localized: "Ready to review?"), subtitle: String(localized: "Test what you've learned today."), action: "study"),
        MessageTemplate(title: String(localized: "Keep the streak going!"), subtitle: String(localized: "A few minutes of study goes a long way."), action: "create"),
        MessageTemplate(title: String(localized: "Your brain will thank you!"), subtitle: String(localized: "Open Keyoku and learn something new."), action: "create"),
        MessageTemplate(title: String(localized: "We miss you!"), subtitle: String(localized: "Don't forget about your flashcards."), action: "study")
    ]

    // Builds an ordered list of 7 messages, leading with context-aware ones when card data is available.
    private func makeMessages(dueCount: Int, stillLearningCount: Int) -> [ScheduledMessage] {
        var pool: [MessageTemplate] = []

        if dueCount > 0 {
            let word = dueCount == 1 ? "card" : "cards"
            pool.append(MessageTemplate(
                title: String(localized: "\(dueCount) \(word) ready for review"),
                subtitle: String(localized: "Revisit them now before they slip away."),
                action: "study"
            ))
        }

        if stillLearningCount > 0 {
            let word = stillLearningCount == 1 ? "card" : "cards"
            pool.append(MessageTemplate(
                title: String(localized: "Keep going — \(stillLearningCount) \(word) in progress"),
                subtitle: String(localized: "The more you practice, the faster you'll learn."),
                action: "study"
            ))
        }

        for generic in genericMessages where pool.count < 7 {
            pool.append(generic)
        }

        return pool.prefix(7).enumerated().map { idx, item in
            ScheduledMessage(title: item.title, subtitle: item.subtitle, day: idx + 1, action: item.action)
        }
    }

    func schedulePushNotificationsForTheNextWeek(dueCount: Int = 0, stillLearningCount: Int = 0) {
        Task {
            do {
                let status = try await LocalNotifications.getNotificationStatus()
                guard status == .authorized else { return }

                LocalNotifications.removeAllPendingNotifications()
                LocalNotifications.removeAllDeliveredNotifications()

                let messages = makeMessages(dueCount: dueCount, stillLearningCount: stillLearningCount)
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
        return calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: futureDate)
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
