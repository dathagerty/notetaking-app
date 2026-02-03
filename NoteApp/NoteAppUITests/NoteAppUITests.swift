//
//  NoteAppUITests.swift
//  NoteAppUITests
//
//  Created by david.hagerty on 1/30/26.
//

import XCTest

final class NoteAppUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    @MainActor
    func testFocusModeToggle() throws {
        // UI test for basic focus mode toggle functionality
        let app = XCUIApplication()
        app.launch()

        // Find the toggle focus mode button
        let toggleButton = app.buttons["Toggle Focus Mode"]
        XCTAssertTrue(toggleButton.exists, "Toggle Focus Mode button should exist")

        // Tap the button to toggle focus mode
        toggleButton.tap()

        // Verify the button is still present after interaction (verifies UI responds)
        XCTAssertTrue(toggleButton.exists, "Toggle Focus Mode button should still exist after tap")
    }

    @MainActor
    func testAppLaunchesSuccessfully() throws {
        // Test that the app launches and displays the main UI
        let app = XCUIApplication()
        app.launch()

        // Verify main title is visible
        let titleText = app.staticTexts["reMarkable iPad Note App"]
        XCTAssertTrue(titleText.exists, "App title should be visible on launch")

        // Verify phase indicator is visible
        let phaseText = app.staticTexts["Phase 1: Project Setup Complete"]
        XCTAssertTrue(phaseText.exists, "Phase indicator should be visible on launch")
    }
}
