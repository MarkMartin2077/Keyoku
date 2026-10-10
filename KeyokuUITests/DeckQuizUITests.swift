//
//  DeckQuizUITests.swift
//  KeyokuUITests
//

// Plays the saved mock quiz from the deck screen's Quizzes strip, end to end.
// The signed-in mock seeds quiz "quiz1" (5 questions) on deck "Spanish Essentials".
// No Apple Intelligence calls: the quiz is already saved.

import XCTest

@MainActor
final class DeckQuizUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPlaySavedQuizFromDeckScreen() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SIGNED_IN"]
        app.launch()

        // Decks tab → the seeded Spanish deck.
        let decksTab = app.descendants(matching: .any)["Decks"]
        XCTAssertTrue(decksTab.waitForExistence(timeout: 10), "Decks tab should appear for a signed-in user")
        decksTab.tap()

        let spanishDeck = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", "Spanish Essentials")).firstMatch
        XCTAssertTrue(spanishDeck.waitForExistence(timeout: 5), "Seeded Spanish deck should be listed")
        spanishDeck.tap()

        // Quizzes strip: the "+" card leads, the saved quiz follows.
        let newQuizCard = app.buttons["NewQuizCard"]
        XCTAssertTrue(newQuizCard.waitForExistence(timeout: 5), "Quizzes strip should show the New Quiz card")

        let quizCard = app.buttons["QuizCard_quiz1"]
        XCTAssertTrue(quizCard.waitForExistence(timeout: 5), "Saved quiz card should be in the strip")

        let stripScreenshot = XCTAttachment(screenshot: app.screenshot())
        stripScreenshot.name = "Deck screen with Quizzes strip"
        stripScreenshot.lifetime = .keepAlways
        add(stripScreenshot)

        quizCard.tap()

        // Answer every question, continuing through the feedback sheet each time.
        let continueButton = app.buttons["QuizFeedbackContinueButton"]
        let doneButton = app.buttons["QuizDoneButton"]
        var answered = 0
        while !doneButton.exists && answered < 20 {
            let firstAnswer = app.buttons["QuizAnswerTile_0"]
            XCTAssertTrue(firstAnswer.waitForExistence(timeout: 5), "Question \(answered + 1) should show its answers")
            firstAnswer.tap()

            XCTAssertTrue(continueButton.waitForExistence(timeout: 5), "Feedback should offer Continue")
            continueButton.tap()
            answered += 1
            _ = doneButton.waitForExistence(timeout: 1)
        }

        // End screen.
        XCTAssertEqual(answered, 5, "The seeded quiz has five questions")
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "End screen should show Done")
        XCTAssertTrue(app.buttons["QuizRetakeButton"].exists, "End screen should offer Retake")

        // Done returns to the deck screen, where the quiz is still in the strip.
        doneButton.tap()
        XCTAssertTrue(quizCard.waitForExistence(timeout: 5), "Quiz card should still be on the deck screen")
    }
}
