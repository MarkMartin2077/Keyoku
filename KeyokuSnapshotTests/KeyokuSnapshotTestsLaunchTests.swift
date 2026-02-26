//
//  KeyokuSnapshotTestsLaunchTests.swift
//  KeyokuSnapshotTests
//
//  Created by Mark Martin on 2/19/26.
//

import XCTest

@MainActor
final class KeyokuSnapshotTestsLaunchTests: XCTestCase {

    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SIGNED_IN"]
        setupSnapshot(app)
        app.launch()

        let homeTab = app.descendants(matching: .any)["Home"]
        _ = homeTab.waitForExistence(timeout: 10)

        snapshot("00_Launch")
    }
}
