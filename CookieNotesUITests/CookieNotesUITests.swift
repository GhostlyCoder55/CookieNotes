//
//  CookieNotesUITests.swift
//  CookieNotesUITests
//

import XCTest

final class CookieNotesUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-CookieNotesSkipTutorial",
            "-CookieNotesSkipConsent",
            "-CookieNotesSkipWelcome"
        ]
        app.launch()
        return app
    }

    @MainActor
    func testEmptyLibraryShowsAddPrompt() throws {
        let app = launchApp()
        XCTAssertTrue(app.tabBars.buttons["Library"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Your journal is empty"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["30 min or less"].exists)
        XCTAssertFalse(app.staticTexts["ADVERTISEMENT"].exists)
    }

    @MainActor
    func testDiscoverTabOpens() throws {
        let app = launchApp()
        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Discover"].tap()
        XCTAssertTrue(app.staticTexts["Find something delicious"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddRecipeScreenOpens() throws {
        let app = launchApp()
        let addButton = app.buttons["Add recipe"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 8))
        addButton.tap()
        XCTAssertTrue(app.navigationBars["New Recipe"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["ADVERTISEMENT"].exists)
    }
}
