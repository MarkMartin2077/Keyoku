//
//  MockLogService.swift
//  KeyokuUnitTests
//
//

// A mock implementation of LogService that captures all tracked
// events in memory. Use this to verify that managers fire the
// correct analytics events during operations.
//
// Usage:
//   let mockLog = MockLogService()
//   let logManager = LogManager(services: [mockLog])
//   let manager = SomeManager(..., logManager: logManager)
//
//   manager.doSomething()
//
//   #expect(mockLog.events.contains { $0.eventName == "Expected_Event" })

import SwiftUI
@testable import Keyoku

@MainActor
class MockLogService: @preconcurrency LogService {

    /// Every event tracked through LogManager ends up here
    var events: [AnyLoggableEvent] = []

    /// Users identified via LogManager.identifyUser
    var identifiedUsers: [(userId: String, name: String?, email: String?)] = []

    /// User properties added via LogManager.addUserProperties
    var userProperties: [[String: Any]] = []

    func identifyUser(userId: String, name: String?, email: String?) {
        identifiedUsers.append((userId, name, email))
    }

    func addUserProperties(dict: [String: Any], isHighPriority: Bool) {
        userProperties.append(dict)
    }

    func deleteUserProfile() { }

    func trackEvent(event: LoggableEvent) {
        events.append(AnyLoggableEvent(
            eventName: event.eventName,
            parameters: event.parameters,
            type: event.type
        ))
    }

    func trackScreenView(event: LoggableEvent) {
        events.append(AnyLoggableEvent(
            eventName: event.eventName,
            parameters: event.parameters,
            type: event.type
        ))
    }

    /// Convenience — check if an event with the given name was tracked
    func hasEvent(named name: String) -> Bool {
        events.contains { $0.eventName == name }
    }

    /// Reset all captured data between tests
    func reset() {
        events.removeAll()
        identifiedUsers.removeAll()
        userProperties.removeAll()
    }
}
