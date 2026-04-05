//
//  MarkdownEditorUITests.swift
//  MarkdownEditorUITests
//
//  Created by Juan Carlos on 6/21/25.
//

import XCTest

final class MarkdownEditorUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testSwiftUIAPIDemoShowsCommandBarAfterTappingEditor() throws {
        let app = XCUIApplication()
        app.launch()

        let swiftUIDemoRow = app.staticTexts["SwiftUI API Demo"]
        XCTAssertTrue(swiftUIDemoRow.waitForExistence(timeout: 5))
        swiftUIDemoRow.tap()

        let dismissKeyboardButton = app.buttons["Dismiss Keyboard"]
        XCTAssertFalse(dismissKeyboardButton.exists)

        let editorSurface = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        editorSurface.tap()

        XCTAssertTrue(dismissKeyboardButton.waitForExistence(timeout: 5))
    }
}
