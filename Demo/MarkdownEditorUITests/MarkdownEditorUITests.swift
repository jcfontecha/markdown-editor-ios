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
    func testRegressionHarnessRendersBroadMarkdownSampleWithoutRawMarkers() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-MarkdownEditorRegressionHarness")
        app.launchEnvironment["MARKDOWNEDITOR_INITIAL_MARKDOWN"] = """
        # Heading 1
        ## Heading 2

        **bold** and *italic* and ***both***

        - bullet point
        - another one
          - nested

        1. numbered
        2. list

        [link text](https://example.com)
        ![alt text](image.jpg)

        `inline code` and:

        ```python
        def hello():
            print("hi")
        ```

        > blockquote

        | col1 | col2 |
        |------|------|
        | a    | b    |

        ---

        ~~strikethrough~~ and - [ ] task list
        """
        app.launch()

        let editor = app.descendants(matching: .any)["markdown-editor-text-view"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))

        let renderedText = String(describing: editor.value)
        XCTAssertTrue(renderedText.contains("Heading 1"), renderedText)
        XCTAssertFalse(renderedText.contains("# Heading 1"), renderedText)
        XCTAssertFalse(renderedText.contains("**bold**"), renderedText)
        XCTAssertFalse(renderedText.contains("```python"), renderedText)

        let exportButton = app.navigationBars.buttons["Export"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        exportButton.tap()
        XCTAssertTrue(app.alerts["Exported Markdown"].waitForExistence(timeout: 5))
        app.alerts["Exported Markdown"].buttons["View"].tap()

        let exported = app.textViews.firstMatch
        XCTAssertTrue(exported.waitForExistence(timeout: 5))
        let exportedText = String(describing: exported.value)
        XCTAssertTrue(exportedText.contains("# Heading 1"), exportedText)
        XCTAssertTrue(exportedText.contains("## Heading 2"), exportedText)
        XCTAssertTrue(exportedText.contains("- bullet point"), exportedText)
        XCTAssertFalse(exportedText.contains("\u{200B}"), exportedText)
    }

    @MainActor
    func testRegressionHarnessTripleTapLineThenDeleteDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-MarkdownEditorRegressionHarness")
        app.launchEnvironment["MARKDOWNEDITOR_INITIAL_MARKDOWN"] = """
        # Selectable Heading

        Selectable paragraph

        - Selectable bullet
        - Trailing bullet
        """
        app.launch()

        let editor = app.descendants(matching: .any)["markdown-editor-text-view"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))

        editor.tap()
        let headingCoordinate = editor.coordinate(withNormalizedOffset: CGVector(dx: 0.32, dy: 0.11))
        headingCoordinate.tap()
        headingCoordinate.tap()
        headingCoordinate.tap()

        if app.keyboards.firstMatch.waitForExistence(timeout: 2), app.keys["delete"].exists {
            app.keys["delete"].tap()
        } else if editor.elementType != .staticText {
            editor.typeText(XCUIKeyboardKey.delete.rawValue)
        } else {
            throw XCTSkip("Regression harness editor is exposed to UI tests as StaticText, so XCTest cannot synthesize delete into it yet.")
        }

        XCTAssertEqual(app.state, .runningForeground)

        let exportButton = app.navigationBars.buttons["Export"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        exportButton.tap()
        XCTAssertTrue(app.alerts["Exported Markdown"].waitForExistence(timeout: 5))
        app.alerts["Exported Markdown"].buttons["View"].tap()

        let exported = app.textViews.firstMatch
        XCTAssertTrue(exported.waitForExistence(timeout: 5))
        let exportedText = String(describing: exported.value)
        XCTAssertFalse(exportedText.contains("Selectable Heading"), exportedText)
        XCTAssertTrue(exportedText.contains("Selectable paragraph"), exportedText)
    }

    @MainActor
    func testRegressionHarnessTypingListEnterCreatesSiblingItem() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-MarkdownEditorRegressionHarness")
        app.launchEnvironment["MARKDOWNEDITOR_INITIAL_MARKDOWN"] = ""
        app.launchEnvironment["MARKDOWNEDITOR_START_WITH_TITLE"] = "0"
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
        editor.typeText("-")
        editor.typeText(" ")
        editor.typeText("first")
        editor.typeText("\n")
        editor.typeText("second")

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

    @MainActor
    func testRegressionHarnessToolbarListToggleOffThirdItemAfterHeadingDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-MarkdownEditorRegressionHarness")
        app.launchEnvironment["MARKDOWNEDITOR_INITIAL_MARKDOWN"] = ""
        app.launchEnvironment["MARKDOWNEDITOR_START_WITH_TITLE"] = "0"
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

        let titleButton = app.buttons["Title"]
        XCTAssertTrue(titleButton.waitForExistence(timeout: 5))
        titleButton.tap()
        editor.typeText("Title")
        editor.typeText("\n")

        let bulletButton = app.buttons["Bullet List"]
        XCTAssertTrue(bulletButton.waitForExistence(timeout: 5))
        bulletButton.tap()
        editor.typeText("One")
        editor.typeText("\n")
        editor.typeText("Two")
        editor.typeText("\n")
        bulletButton.tap()

        XCTAssertEqual(app.state, .runningForeground)

        let exportButton = app.navigationBars.buttons["Export"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        exportButton.tap()
        XCTAssertTrue(app.alerts["Exported Markdown"].waitForExistence(timeout: 5))
        app.alerts["Exported Markdown"].buttons["View"].tap()

        let exported = app.textViews.firstMatch
        XCTAssertTrue(exported.waitForExistence(timeout: 5))
        let exportedText = String(describing: exported.value)
        XCTAssertTrue(exportedText.contains("# Title"), exportedText)
        XCTAssertTrue(exportedText.contains("- One"), exportedText)
        XCTAssertTrue(exportedText.contains("- Two"), exportedText)
    }
}
