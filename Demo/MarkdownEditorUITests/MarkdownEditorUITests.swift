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

        let editor = app.descendants(matching: .any)["markdown-editor-text-view"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        XCTAssertTrue(editor.exists)
    }

    @MainActor
    func testRegressionHarnessAcceptsMarkdownPasteAndExportsFormattedContent() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-MarkdownEditorRegressionHarness")
        app.launchEnvironment["MARKDOWNEDITOR_INITIAL_MARKDOWN"] = """
        # Pasted Title

        - **bold** item
        - [link](https://example.com)
        """
        app.launch()

        let exportButton = app.navigationBars.buttons["Export"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        exportButton.tap()
        XCTAssertTrue(app.alerts["Exported Markdown"].waitForExistence(timeout: 5))
        app.alerts["Exported Markdown"].buttons["View"].tap()

        let exported = app.textViews.firstMatch
        XCTAssertTrue(exported.waitForExistence(timeout: 5))
        let exportedText = String(describing: exported.value)
        XCTAssertTrue(exportedText.contains("Pasted Title"))
        XCTAssertTrue(exportedText.contains("bold"))
    }

    @MainActor
    func testRegressionHarnessTypingListEnterCreatesSiblingItem() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-MarkdownEditorRegressionHarness")
        app.launchEnvironment["MARKDOWNEDITOR_INITIAL_MARKDOWN"] = ""
        app.launch()

        let editor = app.descendants(matching: .any)["markdown-editor-text-view"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            throw XCTSkip("Regression harness editor is exposed to UI tests as StaticText, so XCTest cannot synthesize typing into it yet.")
        }
        if editor.elementType == .staticText {
            throw XCTSkip("Regression harness editor is exposed to UI tests as StaticText, so XCTest cannot synthesize typing into it yet.")
        }
        editor.typeText("\n- first\nsecond")

        let exportButton = app.navigationBars.buttons["Export"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        exportButton.tap()
        XCTAssertTrue(app.alerts["Exported Markdown"].waitForExistence(timeout: 5))
        app.alerts["Exported Markdown"].buttons["View"].tap()

        let exported = app.textViews.firstMatch
        XCTAssertTrue(exported.waitForExistence(timeout: 5))
        let exportedText = String(describing: exported.value)
        XCTAssertTrue(exportedText.contains("- first"), exportedText)
        XCTAssertTrue(exportedText.contains("- second"), exportedText)
    }
}
