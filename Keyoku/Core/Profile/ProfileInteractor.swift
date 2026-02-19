import SwiftUI

@MainActor
protocol ProfileInteractor: GlobalInteractor {
    var currentUser: UserModel? { get }
    var auth: UserAuthInfo? { get }
    var decks: [DeckModel] { get }
    var currentStreakData: CurrentStreakData { get }
    func signOut() async throws
    func deleteAccount() async throws
}

extension CoreInteractor: ProfileInteractor { }
