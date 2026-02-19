//
//  CreateAccountInteractor.swift
//  
//
//  
//
@MainActor
protocol CreateAccountInteractor: GlobalInteractor {
    var decks: [DeckModel] { get }
    var auth: UserAuthInfo? { get }
    func signOutAuthOnly() throws
    func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signInApple() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signInGoogle() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws
    func migrateDecks(_ decksToMigrate: [DeckModel])
}

extension CoreInteractor: CreateAccountInteractor { }
