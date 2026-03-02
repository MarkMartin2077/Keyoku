//
//  SettingsInteractor.swift
//
//
//
//

@MainActor
protocol SettingsInteractor: GlobalInteractor {
    func canRequestPushAuthorization() async -> Bool
    func requestPushAuthorization() async throws -> Bool
}

extension CoreInteractor: SettingsInteractor { }
