//
//  StreakTests.swift
//  KeyokuUnitTests
//
//

// Tests for the gamification streak system (SwiftfulGamification).
// Covers: StreakManager operations, CurrentStreakData computed
// properties, StreakConfiguration settings, and StreakFreeze states.

import Testing
@testable import Keyoku
import SwiftfulGamification
import Foundation

// MARK: - StreakManager Tests

// StreakManager tracks daily study streaks. It comes from the
// SwiftfulGamification package. We use MockStreakServices for
// in-memory testing — no Firebase involved.
//
// The app's streak config (from Dependencies.swift):
//   - streakKey: "daily"
//   - eventsRequiredPerDay: 1
//   - useServerCalculation: false
//   - leewayHours: 0
//   - freezeBehavior: .autoConsumeFreezes
//
// Key concepts:
//   StreakEvent   — a recorded "study session" for the day
//   StreakFreeze  — a "pass" that preserves your streak if you miss a day
//   CurrentStreakData — the computed streak state (current count, status, etc.)

@Suite("StreakManager — Core Functionality")
@MainActor
struct StreakManagerTests {

    // -------------------------------------------------------
    // HELPER — creates a StreakManager matching the app's config
    // -------------------------------------------------------

    private func makeManager(
        streak: CurrentStreakData? = nil,
        mockLog: MockLogService = MockLogService()
    ) -> (StreakManager, MockLogService) {
        let config = StreakConfiguration(
            streakKey: "daily",
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 0,
            freezeBehavior: .autoConsumeFreezes
        )
        let logManager = LogManager(services: [mockLog])
        let manager = StreakManager(
            services: MockStreakServices(streak: streak),
            configuration: config,
            logger: logManager
        )
        return (manager, mockLog)
    }

    // -------------------------------------------------------
    // TEST 1: Fresh manager has no active streak
    // -------------------------------------------------------

    @Test("Fresh manager has no active streak")
    func freshManagerNoStreak() {
        // GIVEN — a manager with no prior data
        let (manager, _) = makeManager()

        // THEN — streak should be zero/nil
        let data = manager.currentStreakData
        #expect(data.currentStreak == nil || data.currentStreak == 0)
        #expect(data.isStreakActive == false)
    }

    // -------------------------------------------------------
    // TEST 2: Adding a streak event returns a valid event
    // -------------------------------------------------------
    // addStreakEvent records that the user studied today.
    // The returned StreakEvent should have a valid ID and
    // not be a freeze event.

    @Test("Adding a streak event returns a valid, non-freeze event")
    func addStreakEventReturnsValidEvent() async throws {
        // GIVEN — a logged-in manager
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")

        // WHEN — we add a streak event
        let event = try await manager.addStreakEvent()

        // THEN — the event should be valid
        #expect(!event.id.isEmpty)
        #expect(event.isFreeze == false)
        #expect(event.freezeId == nil)
    }

    // -------------------------------------------------------
    // TEST 3: Streak activates after first event
    // -------------------------------------------------------

    @Test("Streak becomes active after adding an event")
    func streakActivatesAfterEvent() async throws {
        // GIVEN — a logged-in manager with no streak
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")
        #expect(manager.currentStreakData.isStreakActive == false)

        // WHEN — we add a streak event
        _ = try await manager.addStreakEvent()

        // THEN — the streak should now be active
        #expect(manager.currentStreakData.isStreakActive == true)
    }

    // -------------------------------------------------------
    // TEST 4: Adding an event increments the streak count
    // -------------------------------------------------------

    @Test("Adding an event sets current streak to at least 1")
    func addEventIncrementsStreak() async throws {
        // GIVEN — a logged-in manager
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")

        // WHEN — we add a streak event
        _ = try await manager.addStreakEvent()

        // THEN — current streak should be at least 1
        let streak = manager.currentStreakData.currentStreak ?? 0
        #expect(streak >= 1)
    }

    // -------------------------------------------------------
    // TEST 5: getAllStreakEvents returns recorded events
    // -------------------------------------------------------

    @Test("getAllStreakEvents returns the events we added")
    func getAllStreakEventsReturnsEvents() async throws {
        // GIVEN — a logged-in manager with 2 events
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")
        _ = try await manager.addStreakEvent()
        _ = try await manager.addStreakEvent()

        // WHEN — we fetch all events
        let events = try await manager.getAllStreakEvents()

        // THEN — should have at least 2 events
        #expect(events.count >= 2)
    }

    // -------------------------------------------------------
    // TEST 6: Streak event not allowed when not logged in
    // -------------------------------------------------------
    // The manager should throw when trying to add an event
    // without being logged in.

    @Test("Adding event throws when not logged in")
    func addEventThrowsWhenNotLoggedIn() async {
        // GIVEN — a manager that is NOT logged in
        let (manager, _) = makeManager()

        // WHEN/THEN — adding an event should throw
        do {
            _ = try await manager.addStreakEvent()
            #expect(Bool(false), "Should have thrown")
        } catch {
            // Expected — not logged in
            #expect(true)
        }
    }

    // -------------------------------------------------------
    // TEST 7: Sign out clears in-memory streak data
    // -------------------------------------------------------

    @Test("Sign out resets streak data")
    func signOutResetsStreak() async throws {
        // GIVEN — a logged-in manager with an active streak
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")
        _ = try await manager.addStreakEvent()
        #expect(manager.currentStreakData.isStreakActive == true)

        // WHEN — user signs out
        manager.logOut()

        // THEN — streak should no longer be active
        #expect(manager.currentStreakData.isStreakActive == false)
    }

    // -------------------------------------------------------
    // TEST 8: Streak event includes metadata when provided
    // -------------------------------------------------------

    @Test("Streak event can include custom metadata")
    func streakEventWithMetadata() async throws {
        // GIVEN — a logged-in manager
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")

        // WHEN — we add an event with metadata
        let event = try await manager.addStreakEvent(
            metadata: ["action": "study_session"]
        )

        // THEN — the event should exist and have the metadata
        #expect(!event.id.isEmpty)
        #expect(event.metadata["action"] == "study_session")
    }

    // -------------------------------------------------------
    // TEST 9: deleteAllStreakEvents clears history
    // -------------------------------------------------------

    @Test("Deleting all events clears streak history")
    func deleteAllEventsClears() async throws {
        // GIVEN — a logged-in manager with events
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")
        _ = try await manager.addStreakEvent()

        // WHEN — we delete all events
        try await manager.deleteAllStreakEvents()

        // THEN — event list should be empty
        let events = try await manager.getAllStreakEvents()
        #expect(events.isEmpty)
    }

    // -------------------------------------------------------
    // TEST 10: Recalculate streak updates state
    // -------------------------------------------------------
    // recalculateStreak() re-derives CurrentStreakData from
    // the local event history. Calling it should not crash
    // and should reflect the current state.

    @Test("recalculateStreak does not crash and reflects state")
    func recalculateStreakWorks() async throws {
        // GIVEN — a logged-in manager with an event
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")
        _ = try await manager.addStreakEvent()
        let streakBefore = manager.currentStreakData.currentStreak

        // WHEN — we recalculate
        manager.recalculateStreak()

        // THEN — streak should still be consistent
        let streakAfter = manager.currentStreakData.currentStreak
        #expect(streakAfter == streakBefore)
    }
}

// MARK: - StreakManager — Freeze Tests

@Suite("StreakManager — Freezes")
@MainActor
struct StreakManagerFreezeTests {

    private func makeManager(
        mockLog: MockLogService = MockLogService()
    ) -> (StreakManager, MockLogService) {
        let config = StreakConfiguration(
            streakKey: "daily",
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 0,
            freezeBehavior: .autoConsumeFreezes
        )
        let logManager = LogManager(services: [mockLog])
        let manager = StreakManager(
            services: MockStreakServices(),
            configuration: config,
            logger: logManager
        )
        return (manager, mockLog)
    }

    // -------------------------------------------------------
    // TEST 1: Adding a freeze returns a valid freeze
    // -------------------------------------------------------
    // Freezes are "passes" that protect the streak if you
    // miss a day. They can be earned as rewards.

    @Test("Adding a streak freeze returns a valid freeze")
    func addFreezeReturnsValid() async throws {
        // GIVEN — a logged-in manager
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")

        // WHEN — we add a freeze
        let freeze = try await manager.addStreakFreeze(id: "freeze-1")

        // THEN — the freeze should be valid and available
        #expect(freeze.id == "freeze-1")
        #expect(freeze.isUsed == false)
        #expect(freeze.isAvailable == true)
    }

    // -------------------------------------------------------
    // TEST 2: Freeze with expiration date
    // -------------------------------------------------------

    @Test("Freeze respects expiration date")
    func freezeWithExpiration() async throws {
        // GIVEN — a logged-in manager
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")

        // WHEN — we add a freeze that expires tomorrow
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let freeze = try await manager.addStreakFreeze(id: "temp-freeze", dateExpires: tomorrow)

        // THEN — the freeze should not be expired yet
        #expect(freeze.isExpired == false)
        #expect(freeze.isAvailable == true)
    }

    // -------------------------------------------------------
    // TEST 3: getAllStreakFreezes returns added freezes
    // -------------------------------------------------------

    @Test("getAllStreakFreezes returns the freezes we added")
    func getAllFreezes() async throws {
        // GIVEN — a logged-in manager with 2 freezes
        let (manager, _) = makeManager()
        try await manager.logIn(userId: "user123")
        _ = try await manager.addStreakFreeze(id: "freeze-a")
        _ = try await manager.addStreakFreeze(id: "freeze-b")

        // WHEN — we fetch all freezes
        let freezes = try await manager.getAllStreakFreezes()

        // THEN — should have at least 2
        #expect(freezes.count >= 2)
    }

    // -------------------------------------------------------
    // TEST 4: Adding freeze throws when not logged in
    // -------------------------------------------------------

    @Test("Adding a freeze throws when not logged in")
    func addFreezeThrowsWhenNotLoggedIn() async {
        // GIVEN — a manager that is NOT logged in
        let (manager, _) = makeManager()

        // WHEN/THEN — adding a freeze should throw
        do {
            _ = try await manager.addStreakFreeze(id: "freeze-1")
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(true)
        }
    }
}

// MARK: - CurrentStreakData Tests

// These test the CurrentStreakData struct's computed properties
// using the mock factories. No StreakManager needed — we're
// just verifying the data model's logic.

@Suite("CurrentStreakData — Computed Properties")
@MainActor
struct CurrentStreakDataTests {

    // -------------------------------------------------------
    // TEST 1: Active streak reports correct status
    // -------------------------------------------------------

    @Test("Active streak has isStreakActive == true")
    func activeStreakStatus() {
        // GIVEN — a mock active streak
        let data = CurrentStreakData.mockActive(
            streakKey: "daily",
            currentStreak: 7
        )

        // THEN — it should report as active
        #expect(data.isStreakActive == true)
        #expect(data.currentStreak == 7)
    }

    // -------------------------------------------------------
    // TEST 2: Empty streak is not active
    // -------------------------------------------------------

    @Test("Empty streak has isStreakActive == false")
    func emptyStreakNotActive() {
        // GIVEN — a mock with no events
        let data = CurrentStreakData.mockEmpty(streakKey: "daily")

        // THEN — it should not be active
        #expect(data.isStreakActive == false)
    }

    // -------------------------------------------------------
    // TEST 3: At-risk streak reports correctly
    // -------------------------------------------------------

    @Test("At-risk streak has isStreakAtRisk == true")
    func atRiskStreak() {
        // GIVEN — a mock at-risk streak
        let data = CurrentStreakData.mockAtRisk(
            streakKey: "daily",
            currentStreak: 5
        )

        // THEN — it should be at risk
        #expect(data.isStreakAtRisk == true)
        #expect(data.currentStreak == 5)
    }

    // -------------------------------------------------------
    // TEST 4: Goal-based streak tracks progress
    // -------------------------------------------------------
    // When eventsRequiredPerDay > 1, the streak is "goal-based".
    // The user needs multiple events per day to maintain it.

    @Test("Goal-based streak tracks daily progress")
    func goalBasedProgress() {
        // GIVEN — a streak requiring 3 events/day, with 1 done
        let data = CurrentStreakData.mockGoalBased(
            streakKey: "daily",
            eventsRequiredPerDay: 3,
            todayEventCount: 1
        )

        // THEN — goal should not be met yet
        #expect(data.isGoalMet == false)
        #expect(data.eventsRequiredPerDay == 3)
        #expect(data.todayEventCount == 1)
    }

    // -------------------------------------------------------
    // TEST 5: Goal met when events match requirement
    // -------------------------------------------------------

    @Test("Goal is met when todayEventCount >= eventsRequiredPerDay")
    func goalMetWhenEnoughEvents() {
        // GIVEN — a streak requiring 3 events/day, with 3 done
        let data = CurrentStreakData.mockGoalBased(
            streakKey: "daily",
            eventsRequiredPerDay: 3,
            todayEventCount: 3
        )

        // THEN — goal should be met
        #expect(data.isGoalMet == true)
    }

    // -------------------------------------------------------
    // TEST 6: Active streak with freezes available
    // -------------------------------------------------------

    @Test("Active streak reports available freezes")
    func activeStreakWithFreezes() {
        // GIVEN — an active streak with 2 freezes
        let data = CurrentStreakData.mockActive(
            streakKey: "daily",
            currentStreak: 10,
            freezesAvailableCount: 2
        )

        // THEN — freezes should be available
        #expect(data.freezesAvailableCount == 2)
        #expect(data.currentStreak == 10)
    }

    // -------------------------------------------------------
    // TEST 7: streakKey matches what we pass in
    // -------------------------------------------------------

    @Test("streakKey is set correctly from initialization")
    func streakKeyMatches() {
        // GIVEN — a streak with a specific key
        let data = CurrentStreakData.mockEmpty(streakKey: "daily")

        // THEN — the key should match
        #expect(data.streakKey == "daily")
    }
}

// MARK: - StreakConfiguration Tests

@Suite("StreakConfiguration")
@MainActor
struct StreakConfigurationTests {

    // -------------------------------------------------------
    // TEST 1: App configuration matches expected values
    // -------------------------------------------------------

    @Test("App streak config uses correct values")
    func appConfigValues() {
        // GIVEN — the app's actual streak configuration
        let config = StreakConfiguration(
            streakKey: "daily",
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 0,
            freezeBehavior: .autoConsumeFreezes
        )

        // THEN — values should match what's in Dependencies.swift
        #expect(config.streakKey == "daily")
        #expect(config.eventsRequiredPerDay == 1)
        #expect(config.useServerCalculation == false)
        #expect(config.leewayHours == 0)
        #expect(config.freezeBehavior == .autoConsumeFreezes)
    }

    // -------------------------------------------------------
    // TEST 2: Single event/day is not goal-based
    // -------------------------------------------------------

    @Test("Config with 1 event/day is not goal-based")
    func singleEventNotGoalBased() {
        // GIVEN — a config requiring only 1 event/day
        let config = StreakConfiguration(
            streakKey: "daily",
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 0,
            freezeBehavior: .noFreezes
        )

        // THEN — it should not be goal-based
        #expect(config.isGoalBasedStreak == false)
    }

    // -------------------------------------------------------
    // TEST 3: Multiple events/day is goal-based
    // -------------------------------------------------------

    @Test("Config with 3 events/day is goal-based")
    func multipleEventsIsGoalBased() {
        // GIVEN — a config requiring 3 events/day
        let config = StreakConfiguration(
            streakKey: "daily",
            eventsRequiredPerDay: 3,
            useServerCalculation: false,
            leewayHours: 0,
            freezeBehavior: .noFreezes
        )

        // THEN — it should be goal-based
        #expect(config.isGoalBasedStreak == true)
    }

    // -------------------------------------------------------
    // TEST 4: Zero leeway is strict mode
    // -------------------------------------------------------

    @Test("Zero leeway means strict mode")
    func zeroLeewayIsStrict() {
        // GIVEN — config with 0 leeway hours
        let config = StreakConfiguration(
            streakKey: "daily",
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 0,
            freezeBehavior: .noFreezes
        )

        // THEN — should be strict mode
        #expect(config.isStrictMode == true)
        #expect(config.isTravelFriendly == false)
    }

    // -------------------------------------------------------
    // TEST 5: High leeway is travel-friendly
    // -------------------------------------------------------

    @Test("12+ leeway hours is travel-friendly")
    func highLeewayIsTravelFriendly() {
        // GIVEN — config with 12 hours leeway
        let config = StreakConfiguration(
            streakKey: "daily",
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 12,
            freezeBehavior: .noFreezes
        )

        // THEN — should be travel-friendly and not strict
        #expect(config.isTravelFriendly == true)
        #expect(config.isStrictMode == false)
    }
}

// MARK: - StreakFreeze Model Tests

@Suite("StreakFreeze")
@MainActor
struct StreakFreezeTests {

    // -------------------------------------------------------
    // TEST 1: Unused freeze is available
    // -------------------------------------------------------

    @Test("Unused freeze is available")
    func unusedFreezeAvailable() {
        // GIVEN — a mock unused freeze
        let freeze = StreakFreeze.mockUnused()

        // THEN — it should be available and not used
        #expect(freeze.isUsed == false)
        #expect(freeze.isAvailable == true)
    }

    // -------------------------------------------------------
    // TEST 2: Used freeze is not available
    // -------------------------------------------------------

    @Test("Used freeze is not available")
    func usedFreezeNotAvailable() {
        // GIVEN — a mock used freeze
        let freeze = StreakFreeze.mockUsed()

        // THEN — it should be used and not available
        #expect(freeze.isUsed == true)
        #expect(freeze.isAvailable == false)
    }

    // -------------------------------------------------------
    // TEST 3: Expired freeze is not available
    // -------------------------------------------------------

    @Test("Expired freeze is not available")
    func expiredFreezeNotAvailable() {
        // GIVEN — a mock expired freeze
        let freeze = StreakFreeze.mockExpired()

        // THEN — it should be expired and not available
        #expect(freeze.isExpired == true)
        #expect(freeze.isAvailable == false)
    }
}
