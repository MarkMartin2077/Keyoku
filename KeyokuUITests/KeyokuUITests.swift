//
//  KeyokuUITests.swift
//  KeyokuUITests
//
//

// ============================================================
// UI TESTS — What are they?
// ============================================================
//
// Unlike UNIT TESTS (which test code in isolation), UI TESTS
// launch the ACTUAL APP in a simulator and interact with it
// like a real user would — tapping buttons, swiping, typing,
// and verifying what's on screen.
//
// Think of it like a robot user:
//   1. Launch the app
//   2. Look for a button on screen
//   3. Tap it
//   4. Verify the next screen appeared
//
// Key differences from unit tests:
//
//   UNIT TESTS (Swift Testing)          UI TESTS (XCTest)
//   ──────────────────────────          ─────────────────
//   import Testing                      import XCTest
//   @Test func name()                   func testName()     (must start with "test")
//   #expect(condition)                  XCTAssert(condition)
//   Test code directly                  Test the running app
//   Fast (milliseconds)                 Slower (seconds per test)
//   No simulator needed                 Launches full simulator
//
// UI tests use XCTest (not Swift Testing) because they need
// XCUIApplication to control the simulator.
//
// ============================================================
// HOW THIS APP SUPPORTS UI TESTING
// ============================================================
//
// The app has a built-in testing mode:
//
//   1. AppDelegate checks `Utilities.isUITesting`
//   2. If true, it forces `.mock(isSignedIn:)` config
//   3. It checks for "SIGNED_IN" launch argument
//   4. KeyokuApp shows `AppViewForUITesting` instead of the real app
//
// This means we can control the app's starting state:
//   - ["UI_TESTING"]               → Onboarding (signed out, mock data)
//   - ["UI_TESTING", "SIGNED_IN"]  → Main app (signed in, mock data)
//
// "UI_TESTING" is ALWAYS required — it activates Utilities.isUITesting.
// Without it, the app ignores all other test arguments.
//
// ============================================================
// XCUIAPPLICATION CHEAT SHEET
// ============================================================
//
// Finding elements:
//   app.buttons["Get Started"]          — find button by label
//   app.buttons["StartButton"]          — find by accessibilityIdentifier
//   app.staticTexts["Keyoku"]           — find label/text
//   app.textFields["Enter question"]    — find text field
//   app.navigationBars["Deck Name"]     — find nav bar
//
// Interacting:
//   element.tap()                       — tap an element
//   element.swipeLeft()                 — swipe gesture
//   element.typeText("hello")           — type into a field
//
// Checking state:
//   element.exists                      — is the element in the hierarchy?
//   element.isHittable                  — is it visible AND tappable?
//   element.waitForExistence(timeout:)  — wait up to N seconds for it
//   element.label                       — the text content of the element
//
// ============================================================

import XCTest

// MARK: - Keyoku UI Tests

// -------------------------------------------------------
// PATTERN — Local `let app` in each test
// -------------------------------------------------------
// Each test creates its own XCUIApplication as a LOCAL
// variable. This avoids @MainActor concurrency conflicts
// with XCTestCase's setUp/tearDown (which are nonisolated
// overrides that can't access @MainActor properties).
//
// setUp only sets continueAfterFailure = false — if one
// assertion fails, the test stops immediately instead of
// producing confusing cascading failures.
// -------------------------------------------------------

@MainActor
final class KeyokuUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // -------------------------------------------------------
    // TEST 1: Full onboarding flow
    // -------------------------------------------------------
    // Walks through the entire onboarding experience:
    //   Welcome → Get Started → 4 carousel pages → Main App
    //
    // This is the most valuable onboarding test because it
    // proves the whole flow works end-to-end in a single launch.

    func testOnboardingFlow() throws {
        // "UI_TESTING" is REQUIRED — it tells AppDelegate to use mock config.
        // No "SIGNED_IN" = mock config with isSignedIn: false = onboarding.
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()

        // Welcome Screen — verify content is visible
        let title = app.staticTexts["Keyoku"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        let subtitle = app.staticTexts["Study smarter with AI-powered flashcards"]
        XCTAssertTrue(subtitle.exists)

        // Verify Sign In link exists (wrapped in .anyButton = button type)
        let signInButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Sign in")
        )
        XCTAssertTrue(signInButton.firstMatch.exists)

        // Verify policy links exist
        // Link() element type varies by iOS — descendants searches all types
        let termsLink = app.descendants(matching: .any)["Terms of Service"]
        XCTAssertTrue(termsLink.waitForExistence(timeout: 5))

        let privacyLink = app.descendants(matching: .any)["Privacy Policy"]
        XCTAssertTrue(privacyLink.exists)

        // Tap Get Started → Onboarding carousel
        app.buttons["StartButton"].tap()

        // Page 1: Create with Intelligence
        let page1 = app.staticTexts["Create with Intelligence"]
        XCTAssertTrue(page1.waitForExistence(timeout: 5))

        // Tap Continue → Page 2
        let actionButton = app.buttons["FinishButton"]
        XCTAssertTrue(actionButton.waitForExistence(timeout: 3))
        actionButton.tap()

        let page2 = app.staticTexts["Organize Your Knowledge"]
        XCTAssertTrue(page2.waitForExistence(timeout: 5))

        // Tap Continue → Page 3
        actionButton.tap()

        let page3 = app.staticTexts["Study Your Way"]
        XCTAssertTrue(page3.waitForExistence(timeout: 5))

        // Tap Continue → Page 4
        actionButton.tap()

        let page4 = app.staticTexts["Build a Study Habit"]
        XCTAssertTrue(page4.waitForExistence(timeout: 5))

        // On the last page, button label changes to "Get Started"
        let getStartedButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Get Started")
        )
        XCTAssertTrue(getStartedButton.firstMatch.exists)

        // Tap Get Started → Main App
        actionButton.tap()

        // Verify tab bar appeared (onboarding complete)
        let homeTab = app.tabBars.buttons.firstMatch
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
    }

    // -------------------------------------------------------
    // TEST 2: Swipe gesture advances carousel pages
    // -------------------------------------------------------
    // The onboarding carousel is a TabView, so users can
    // swipe left instead of tapping Continue.

    func testOnboardingSwipeNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()

        // Navigate to carousel
        app.buttons["StartButton"].tap()

        let page1 = app.staticTexts["Create with Intelligence"]
        XCTAssertTrue(page1.waitForExistence(timeout: 5))

        // Swipe left → Page 2
        app.swipeLeft()

        let page2 = app.staticTexts["Organize Your Knowledge"]
        XCTAssertTrue(page2.waitForExistence(timeout: 5))
    }

    // -------------------------------------------------------
    // TEST 3: Signed-in user skips onboarding
    // -------------------------------------------------------
    // A returning user with "SIGNED_IN" launch argument should
    // go straight to the main app tab bar, not onboarding.
    //
    // We use a 10s timeout because the app runs checkUserStatus()
    // on launch, which does an async login before the tab bar appears.

    func testSignedInFlow() throws {
        // "UI_TESTING" activates mock config, "SIGNED_IN" starts as logged in
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SIGNED_IN"]
        app.launch()

        // Verify main app tabs are visible (not onboarding)
        // descendants(matching: .any) handles iOS 18 Tab API differences
        let homeTab = app.descendants(matching: .any)["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))

        let decksTab = app.descendants(matching: .any)["Decks"]
        XCTAssertTrue(decksTab.exists)

        // Onboarding should NOT be present
        let startButton = app.buttons["StartButton"]
        XCTAssertFalse(startButton.exists)
    }

    // =========================================================
    // DECK CREATION FLOW
    // =========================================================
    //
    // These tests cover creating a deck from the Home screen:
    //   Home → "Create New" → Create Deck sheet → fill → create
    //
    // All launch as signed-in user (mock decks pre-loaded).
    // AI generation is NOT tested — FoundationModels doesn't
    // run in mock/test environments. Tests focus on "Start Empty"
    // mode and general sheet behavior.
    //
    // =========================================================

    // MARK: - Deck Creation Helpers

    /// Launches signed-in and waits for Home to load.
    private func launchSignedIn() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SIGNED_IN"]
        app.launch()

        let homeTab = app.descendants(matching: .any)["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10), "Home tab should appear for signed-in user")

        return app
    }

    /// Opens the Create Deck sheet from the Home screen.
    private func openCreateSheet(app: XCUIApplication) {
        let createButton = app.buttons["CreateNewButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "Create New button should exist on Home")
        createButton.tap()

        let navBar = app.navigationBars["Create"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Create sheet should appear")
    }

    // -------------------------------------------------------
    // TEST 4: Create deck sheet opens from Home
    // -------------------------------------------------------
    // Tapping "Create New" on the Home screen should present
    // the Create Deck sheet with a Cancel button, deck name
    // field, and the Generate button (default mode).

    func testCreateDeckSheetOpens() throws {
        let app = launchSignedIn()
        openCreateSheet(app: app)

        // Cancel button in toolbar
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")

        // Deck name text field
        let nameField = app.textFields["DeckNameField"]
        XCTAssertTrue(nameField.exists, "Deck name field should exist")

        // Default mode is Generate — button should be visible
        let generateButton = app.buttons["GenerateButton"]
        XCTAssertTrue(generateButton.exists, "Generate button should be visible in default mode")
    }

    // -------------------------------------------------------
    // TEST 5: Cancel dismisses the sheet
    // -------------------------------------------------------
    // Tapping Cancel should dismiss the Create Deck sheet
    // and return to the Home screen.

    func testCreateDeckCancelDismisses() throws {
        let app = launchSignedIn()
        openCreateSheet(app: app)

        // Tap Cancel
        app.buttons["Cancel"].tap()

        // Home tab should still be visible (sheet dismissed)
        let homeTab = app.descendants(matching: .any)["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "Home should be visible after cancel")

        // Create sheet nav bar should be gone
        let navBar = app.navigationBars["Create"]
        XCTAssertFalse(navBar.exists, "Create sheet should be dismissed")
    }

    // -------------------------------------------------------
    // TEST 6: Create Empty Deck button disabled without name
    // -------------------------------------------------------
    // Switching to "Start Empty" mode without entering a name
    // should show the button as disabled.

    func testCreateEmptyDisabledWithoutName() throws {
        let app = launchSignedIn()
        openCreateSheet(app: app)

        // Switch to Start Empty mode
        app.buttons["Start Empty"].tap()

        // Button should exist but be disabled (no name)
        let createButton = app.buttons["CreateEmptyDeckButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3), "Create Empty Deck button should exist")
        XCTAssertFalse(createButton.isEnabled, "Should be disabled without a name")
    }

    // -------------------------------------------------------
    // TEST 7: Create Empty Deck button enables with name
    // -------------------------------------------------------
    // Entering a deck name in "Start Empty" mode should make
    // the button enabled.

    func testCreateEmptyEnablesWithName() throws {
        let app = launchSignedIn()
        openCreateSheet(app: app)

        // Switch to Start Empty
        app.buttons["Start Empty"].tap()

        // Enter a deck name
        let nameField = app.textFields["DeckNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        nameField.typeText("My Test Deck")

        // Button should now be enabled
        let createButton = app.buttons["CreateEmptyDeckButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 3))
        XCTAssertTrue(createButton.isEnabled, "Should be enabled after entering a name")
    }

    // -------------------------------------------------------
    // TEST 8: Successfully create an empty deck
    // -------------------------------------------------------
    // Full flow: open sheet → Start Empty → type name → tap
    // Create → sheet dismissed → back on Home.
    //
    // The signed-in mock user already has decks, so no
    // first-deck celebration should appear.

    func testCreateEmptyDeckSuccess() throws {
        let app = launchSignedIn()
        openCreateSheet(app: app)

        // Switch to Start Empty
        app.buttons["Start Empty"].tap()

        // Enter a deck name
        let nameField = app.textFields["DeckNameField"]
        nameField.tap()
        nameField.typeText("Physics 101")

        // Tap Create Empty Deck
        let createButton = app.buttons["CreateEmptyDeckButton"]
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()

        // Home tab should reappear (sheet dismissed)
        let homeTab = app.descendants(matching: .any)["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "Home should be visible after creation")

        // Create sheet should be gone
        let navBar = app.navigationBars["Create"]
        XCTAssertFalse(navBar.exists, "Sheet should dismiss after creating deck")
    }

    // -------------------------------------------------------
    // TEST 9: Mode switching between Generate and Start Empty
    // -------------------------------------------------------
    // The segmented picker toggles UI sections:
    //   Generate → Source Text section + Generate button
    //   Empty    → Create Empty Deck button, no source text

    func testCreationModeSwitching() throws {
        let app = launchSignedIn()
        openCreateSheet(app: app)

        // Default is Generate mode
        let generateButton = app.buttons["GenerateButton"]
        XCTAssertTrue(generateButton.exists, "Generate button should exist in generate mode")

        let sourceTextHeader = app.staticTexts["Source Text"]
        XCTAssertTrue(sourceTextHeader.exists, "Source Text should exist in generate mode")

        // Switch to Start Empty
        app.buttons["Start Empty"].tap()

        let createEmptyButton = app.buttons["CreateEmptyDeckButton"]
        XCTAssertTrue(createEmptyButton.waitForExistence(timeout: 3), "Create Empty button should appear")

        // Generate-only elements hidden
        XCTAssertFalse(generateButton.exists, "Generate button hidden in empty mode")
        XCTAssertFalse(sourceTextHeader.exists, "Source Text hidden in empty mode")

        // Switch back to Generate
        app.buttons["Generate with AI"].tap()

        XCTAssertTrue(generateButton.waitForExistence(timeout: 3), "Generate button should reappear")
        XCTAssertTrue(sourceTextHeader.waitForExistence(timeout: 3), "Source Text should reappear")
    }

    // -------------------------------------------------------
    // TEST 10: Color selection
    // -------------------------------------------------------
    // Default color is Blue. Tapping another color selects it
    // and deselects Blue. Colors use accessibility labels like
    // "Blue, selected" and "Orange".

    func testColorSelection() throws {
        let app = launchSignedIn()
        openCreateSheet(app: app)

        // Blue should be selected by default
        let blueSelected = app.buttons["Blue, selected"]
        XCTAssertTrue(blueSelected.waitForExistence(timeout: 3), "Blue should be selected by default")

        // Tap Orange
        let orangeButton = app.buttons["Orange"]
        XCTAssertTrue(orangeButton.exists, "Orange color option should exist")
        orangeButton.tap()

        // Orange now selected, Blue deselected
        let orangeSelected = app.buttons["Orange, selected"]
        XCTAssertTrue(orangeSelected.waitForExistence(timeout: 3), "Orange should become selected")

        let blueUnselected = app.buttons["Blue"]
        XCTAssertTrue(blueUnselected.exists, "Blue should no longer be selected")
    }

    // -------------------------------------------------------
    // TEST 11: Generate button disabled without source text
    // -------------------------------------------------------
    // In Generate mode, entering only a deck name (no source
    // text) keeps the Generate button disabled.

    func testGenerateDisabledWithoutSourceText() throws {
        let app = launchSignedIn()
        openCreateSheet(app: app)

        // Generate button disabled initially (no name or source)
        let generateButton = app.buttons["GenerateButton"]
        XCTAssertTrue(generateButton.exists)
        XCTAssertFalse(generateButton.isEnabled, "Should be disabled with no name or source text")

        // Enter only a deck name
        let nameField = app.textFields["DeckNameField"]
        nameField.tap()
        nameField.typeText("History Deck")

        // Still disabled — no source text
        XCTAssertFalse(generateButton.isEnabled, "Should be disabled with name but no source text")
    }

    // -------------------------------------------------------
    // TEST 12: Create deck with custom color
    // -------------------------------------------------------
    // End-to-end: select non-default color → name → create.
    // Verifies the full flow works with customized settings.

    func testCreateDeckWithCustomColor() throws {
        let app = launchSignedIn()
        openCreateSheet(app: app)

        // Switch to Start Empty
        app.buttons["Start Empty"].tap()

        // Select Teal
        let tealButton = app.buttons["Teal"]
        XCTAssertTrue(tealButton.waitForExistence(timeout: 3))
        tealButton.tap()

        let tealSelected = app.buttons["Teal, selected"]
        XCTAssertTrue(tealSelected.waitForExistence(timeout: 3), "Teal should become selected")

        // Enter name and create
        let nameField = app.textFields["DeckNameField"]
        nameField.tap()
        nameField.typeText("Chemistry Notes")

        let createButton = app.buttons["CreateEmptyDeckButton"]
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()

        // Sheet should dismiss
        let homeTab = app.descendants(matching: .any)["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "Home should be visible after creation")
    }
}
