//
//  KeyokuSnapshotTests.swift
//  KeyokuSnapshotTests
//
//  Created by Mark Martin on 2/19/26.
//
//  Fastlane Snapshot tests for App Store screenshots.
//  Each test navigates to a key screen and captures a snapshot.
//

import XCTest

@MainActor
final class KeyokuSnapshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launchApp(signedIn: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["UI_TESTING"]
        if signedIn {
            args.append("SIGNED_IN")
        }
        app.launchArguments = args
        setupSnapshot(app)
        app.launch()
        return app
    }

    // MARK: - Snapshots

    func test01WelcomeScreen() {
        let app = launchApp(signedIn: false)

        let title = app.staticTexts["Keyoku"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        snapshot("01_Welcome")
    }

    func test02HomeScreen() {
        let app = launchApp(signedIn: true)

        let homeTab = app.descendants(matching: .any)["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))

        snapshot("02_Home")
    }

    func test03DecksScreen() {
        let app = launchApp(signedIn: true)

        let decksTab = app.descendants(matching: .any)["Decks"]
        XCTAssertTrue(decksTab.waitForExistence(timeout: 10))
        decksTab.tap()

        sleep(1)

        snapshot("03_Decks")
    }

    func test04DeckDetail() {
        let app = launchApp(signedIn: true)

        let homeTab = app.descendants(matching: .any)["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))

        // Tap the first deck card on the Home screen
        let deckCard = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "card")
        ).firstMatch
        XCTAssertTrue(deckCard.waitForExistence(timeout: 5))
        deckCard.tap()

        // Wait for Deck Detail to load
        let practiceButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Practice")
        ).firstMatch
        XCTAssertTrue(practiceButton.waitForExistence(timeout: 5))

        snapshot("04_DeckDetail")
    }

    func test05PracticeSession() {
        let app = launchApp(signedIn: true)

        let homeTab = app.descendants(matching: .any)["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))

        // Navigate to a deck
        let deckCard = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "card")
        ).firstMatch
        XCTAssertTrue(deckCard.waitForExistence(timeout: 5))
        deckCard.tap()

        // Tap Practice
        let practiceButton = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Practice")
        ).firstMatch
        XCTAssertTrue(practiceButton.waitForExistence(timeout: 5))
        practiceButton.tap()

        sleep(1)

        snapshot("05_Practice")
    }

    func test06ProfileScreen() {
        let app = launchApp(signedIn: true)

        let profileTab = app.descendants(matching: .any)["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
        profileTab.tap()

        sleep(1)

        snapshot("06_Profile")
    }

    func test07CreateDeck() {
        let app = launchApp(signedIn: true)

        let homeTab = app.descendants(matching: .any)["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))

        // Tap Create New
        let createButton = app.buttons["CreateNewButton"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        // Wait for Create sheet to appear
        let navBar = app.navigationBars["Create"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        snapshot("07_CreateDeck")
    }
}
