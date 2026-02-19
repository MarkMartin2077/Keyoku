//
//  KeyokuUnitTests.swift
//  KeyokuUnitTests
//
//

// Swift Testing framework — the modern way to write tests in Swift.
// Key APIs:
//   #expect(condition)       — asserts a condition is true
//   #expect(throws:)         — asserts that code throws a specific error
//   @Test func name()        — marks a function as a test
//   @Suite("Name")           — groups related tests together

import Testing
@testable import Keyoku      // @testable lets us access internal types (AuthManager, etc.)
import SwiftfulAuthenticating // needed for UserAuthInfo, MockAuthService, etc.
import Foundation

// MARK: - Auth Manager Tests

// @Suite groups related tests — think of it like a chapter in a test book.
// Every test inside follows the same pattern:
//
//   GIVEN — set up the scenario (create mocks, configure state)
//   WHEN  — perform the action you're testing
//   THEN  — verify the result with #expect(...)
//
// Note: AuthManager and MockAuthService are @MainActor, so we mark
// the entire suite @MainActor. This means all tests run on the main
// actor — no need for `await` on every property access.

@Suite("AuthManager Tests")
@MainActor
struct AuthManagerTests {

    // -------------------------------------------------------
    // HELPER — creates an AuthManager with a MockLogService
    // -------------------------------------------------------
    // By passing MockLogService → LogManager → AuthManager,
    // we can verify that the correct analytics events were
    // fired during each operation. This catches accidental
    // deletion of tracking calls.

    private func makeAuthManager(
        user: UserAuthInfo? = nil,
        mockLog: MockLogService = MockLogService()
    ) -> (AuthManager, MockLogService) {
        let logManager = LogManager(services: [mockLog])
        let authManager = AuthManager(service: MockAuthService(user: user), logger: logManager)
        return (authManager, mockLog)
    }

    // -------------------------------------------------------
    // TEST 1: A signed-out user has no auth
    // -------------------------------------------------------
    // This is the simplest possible test. We create an AuthManager
    // with NO user, then verify .auth is nil.

    @Test("Auth is nil when no user is signed in")
    func authIsNilWhenNotSignedIn() {
        // GIVEN — an AuthManager with no user
        let (authManager, _) = makeAuthManager()

        // THEN — auth should be nil
        #expect(authManager.auth == nil)
    }

    // -------------------------------------------------------
    // TEST 2: A signed-in user has auth
    // -------------------------------------------------------
    // We pass a mock user into MockAuthService, which means
    // AuthManager should pick it up immediately.

    @Test("Auth is populated when user is signed in")
    func authExistsWhenSignedIn() {
        // GIVEN — an AuthManager initialized with a mock user
        let mockUser = UserAuthInfo.mock()
        let (authManager, _) = makeAuthManager(user: mockUser)

        // THEN — auth should exist and match the mock user's uid
        #expect(authManager.auth != nil)
        #expect(authManager.auth?.uid == mockUser.uid)
    }

    // -------------------------------------------------------
    // TEST 3: getAuthId() throws when not signed in
    // -------------------------------------------------------
    // This tests the error path. When nobody is signed in,
    // calling getAuthId() should throw an error.

    @Test("getAuthId throws when not signed in")
    func getAuthIdThrowsWhenNotSignedIn() {
        // GIVEN — an AuthManager with no user
        let (authManager, _) = makeAuthManager()

        // WHEN/THEN — getAuthId() should throw
        #expect(throws: (any Error).self) {
            try authManager.getAuthId()
        }
    }

    // -------------------------------------------------------
    // TEST 4: getAuthId() returns uid when signed in
    // -------------------------------------------------------

    @Test("getAuthId returns uid when signed in")
    func getAuthIdReturnsUid() throws {
        // GIVEN — an AuthManager with a signed-in user
        let mockUser = UserAuthInfo.mock()
        let (authManager, _) = makeAuthManager(user: mockUser)

        // WHEN — we get the auth id
        let authId = try authManager.getAuthId()

        // THEN — it should match the mock user's uid
        #expect(authId == mockUser.uid)
    }

    // -------------------------------------------------------
    // TEST 5: Sign in anonymously sets auth and tracks events
    // -------------------------------------------------------
    // This tests an async action. We start with no user,
    // sign in, then verify auth is populated AND that the
    // correct analytics events were fired.

    @Test("Signing in anonymously sets auth and tracks events")
    func signInAnonymouslySetsAuth() async throws {
        // GIVEN — an AuthManager with no user
        let (authManager, mockLog) = makeAuthManager()
        #expect(authManager.auth == nil)

        // WHEN — user signs in anonymously
        let result = try await authManager.signInAnonymously()

        // THEN — auth should be set and result should contain a user
        #expect(authManager.auth != nil)
        #expect(result.user.uid == authManager.auth?.uid)

        // AND — analytics events should have been tracked
        #expect(mockLog.hasEvent(named: "Auth_SignIn_Start"))
        #expect(mockLog.hasEvent(named: "Auth_SignIn_Success"))
    }

    // -------------------------------------------------------
    // TEST 6: Sign out clears auth and tracks events
    // -------------------------------------------------------
    // Start signed in, sign out, verify auth is nil and
    // that sign-out events were tracked.

    @Test("Signing out clears auth and tracks events")
    func signOutClearsAuth() throws {
        // GIVEN — an AuthManager with a signed-in user
        let (authManager, mockLog) = makeAuthManager(user: .mock())
        #expect(authManager.auth != nil)

        // WHEN — user signs out
        try authManager.signOut()

        // THEN — auth should be nil
        #expect(authManager.auth == nil)

        // AND — sign-out events should have been tracked
        #expect(mockLog.hasEvent(named: "Auth_SignOut_Start"))
        #expect(mockLog.hasEvent(named: "Auth_SignOut_Success"))
    }

    // -------------------------------------------------------
    // TEST 7: Delete account clears auth and tracks events
    // -------------------------------------------------------

    @Test("Deleting account clears auth and tracks events")
    func deleteAccountClearsAuth() async throws {
        // GIVEN — an AuthManager with a signed-in user
        let (authManager, mockLog) = makeAuthManager(user: .mock())
        #expect(authManager.auth != nil)

        // WHEN — user deletes their account
        try await authManager.deleteAccount()

        // THEN — auth should be nil
        #expect(authManager.auth == nil)

        // AND — delete events should have been tracked
        #expect(mockLog.hasEvent(named: "Auth_DeleteAccount_Start"))
        #expect(mockLog.hasEvent(named: "Auth_DeleteAccount_Success"))
    }

    // -------------------------------------------------------
    // TEST 8: Sign in → Sign out → Sign in works
    // -------------------------------------------------------
    // Tests the full lifecycle to make sure state resets properly.

    @Test("Full sign-in, sign-out, sign-in lifecycle works")
    func fullAuthLifecycle() async throws {
        // GIVEN — a fresh AuthManager
        let (authManager, _) = makeAuthManager()
        #expect(authManager.auth == nil)

        // WHEN — sign in
        try await authManager.signInAnonymously()

        // THEN — auth exists
        #expect(authManager.auth != nil)

        // WHEN — sign out
        try authManager.signOut()

        // THEN — auth is cleared
        #expect(authManager.auth == nil)

        // WHEN — sign in again
        try await authManager.signInAnonymously()

        // THEN — auth exists again
        #expect(authManager.auth != nil)
    }

    // -------------------------------------------------------
    // TEST 9: Mock user properties are correct
    // -------------------------------------------------------
    // Verifies the mock data itself — good practice to make sure
    // your test fixtures are what you expect.

    @Test("Mock user has expected properties")
    func mockUserHasExpectedProperties() {
        // GIVEN — a mock user
        let user = UserAuthInfo.mock(isAnonymous: false)

        // THEN — properties should match what .mock() provides
        #expect(user.uid == "mock_user_123")
        #expect(user.email == "hello@gmail.com")
        #expect(user.isAnonymous == false)
        #expect(user.displayName == "Joe")
    }

    // -------------------------------------------------------
    // TEST 10: Anonymous mock user is marked anonymous
    // -------------------------------------------------------

    @Test("Anonymous mock user has correct properties")
    func anonymousMockUser() {
        // GIVEN — a mock anonymous user
        let user = UserAuthInfo.mock(isAnonymous: true)

        // THEN — should be anonymous with no providers
        #expect(user.isAnonymous == true)
        #expect(user.authProviders.isEmpty)
    }
}
