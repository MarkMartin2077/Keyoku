import SwiftUI

@MainActor
protocol ProfileInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var auth: UserAuthInfo? { get }
    var decks: [DeckModel] { get }
    var currentStreakData: CurrentStreakData { get }
    var isPremium: Bool { get }
    func signOut() async throws
    func deleteAccount() async throws
    var isReminderEnabled: Bool { get }
    var reminderHour: Int { get }
    var reminderMinute: Int { get }
    func setReminderEnabled(_ isOn: Bool) async throws
    func setReminderTime(hour: Int, minute: Int)
    func requestPushAuthorization() async throws -> Bool
    func canRequestPushAuthorization() async -> Bool
}

extension CoreInteractor: ProfileInteractor { }
