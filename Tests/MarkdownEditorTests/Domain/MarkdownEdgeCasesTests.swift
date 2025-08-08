import XCTest
@testable import MarkdownEditor

final class MarkdownEdgeCasesTests: XCTestCase {
    var documentService: MarkdownDocumentService!
    var formattingService: MarkdownFormattingService!
    var stateService: MarkdownStateService!
    var context: MarkdownCommandContext!

    override func setUp() {
        super.setUp()
        documentService = DefaultMarkdownDocumentService()
        formattingService = DefaultMarkdownFormattingService(documentService: documentService)
        stateService = DefaultMarkdownStateService(documentService: documentService, formattingService: formattingService)
        context = MarkdownCommandContext(documentService: documentService, formattingService: formattingService, stateService: stateService)
    }

    // MARK: - Block Type Conversions

    func testParagraphToParagraphNoOp() {
        let state = MarkdownEditorState.withParagraph("Hello")
        let cmd = SetBlockTypeCommand(blockType: .paragraph, at: state.selection.start, context: context)
        let result = cmd.execute(on: state)
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.content, "Hello")
            XCTAssertEqual(newState.currentBlockType, .paragraph)
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        }
    }

    func testParagraphToHeadingAllLevels() {
        for level in MarkdownBlockType.HeadingLevel.allCases {
            let state = MarkdownEditorState.withParagraph("Title")
            let cmd = SetBlockTypeCommand(blockType: .heading(level: level), at: state.selection.start, context: context)
            let result = cmd.execute(on: state)
            switch result {
            case .success(let newState):
                let prefix = String(repeating: "#", count: level.rawValue) + " "
                XCTAssertTrue(newState.content.hasPrefix(prefix))
                XCTAssertEqual(newState.currentBlockType, .heading(level: level))
            case .failure(let error):
                XCTFail("Unexpected failure for level \(level): \(error)")
            }
        }
    }

    func testHeadingToParagraphPreservesText() {
        let state = MarkdownEditorState.withHeader(.h2, text: "Heading Text")
        let cmd = SetBlockTypeCommand(blockType: .paragraph, at: state.selection.start, context: context)
        let result = cmd.execute(on: state)
        switch result {
        case .success(let newState):
            XCTAssertEqual(newState.currentBlockType, .paragraph)
            XCTAssertEqual(newState.content, "Heading Text")
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        }
    }

    func testQuoteToListAndBack() {
        let state = MarkdownEditorState(content: "> Quote", selection: TextRange(at: .start), currentBlockType: .quote)
        let toList = SetBlockTypeCommand(blockType: .unorderedList, at: state.selection.start, context: context)
        let toListResult = toList.execute(on: state)
        guard case .success(let listState) = toListResult else { return XCTFail("quote->list failed") }
        XCTAssertEqual(listState.currentBlockType, .unorderedList)
        XCTAssertTrue(listState.content.hasPrefix("- "))

        let backToParagraph = SetBlockTypeCommand(blockType: .paragraph, at: listState.selection.start, context: context)
        let backResult = backToParagraph.execute(on: listState)
        switch backResult {
        case .success(let paraState):
            XCTAssertEqual(paraState.currentBlockType, .paragraph)
            XCTAssertEqual(paraState.content, "Quote")
        case .failure(let error):
            XCTFail("list->paragraph failed: \(error)")
        }
    }

    // MARK: - Inline Formatting Rules

    func testInlineFormattingIncompatibilityWithCode() {
        let state = MarkdownEditorState.withParagraph("Hello World")
        let range = TextRange(start: DocumentPosition(blockIndex: 0, offset: 0), end: DocumentPosition(blockIndex: 0, offset: 5))

        // Apply bold first
        let bold = ApplyFormattingCommand(formatting: [.bold], to: range, operation: .apply, context: context)
        guard case .success(let boldState) = bold.execute(on: state) else { return XCTFail("bold apply failed") }

        // Now try to apply code (should fail or drop others per rules)
        let code = ApplyFormattingCommand(formatting: [.code], to: range, operation: .apply, context: context)
        let result = code.execute(on: boldState)
        switch result {
        case .success(let s):
            // If success, ensure code is present and others removed by our simplified model
            XCTAssertTrue(s.currentFormatting.contains(.code))
        case .failure:
            // Also acceptable per rules
            XCTAssertTrue(true)
        }
    }

    func testInlineFormattingMultiBlockSelectionIsRejected() {
        let state = MarkdownEditorState(content: "Para 1\n\nPara 2", selection: TextRange(at: .start))
        let range = TextRange(start: DocumentPosition(blockIndex: 0, offset: 0), end: DocumentPosition(blockIndex: 1, offset: 2))
        let cmd = ApplyFormattingCommand(formatting: [.bold], to: range, operation: .apply, context: context)
        let result = cmd.execute(on: state)
        switch result {
        case .success:
            XCTFail("Multi-block formatting should be rejected")
        case .failure:
            XCTAssertTrue(true)
        }
    }

    func testFormattingDisallowedInCodeBlocks() {
        let content = "```\ncode\n```"
        let state = MarkdownEditorState(content: content, selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 0)), currentBlockType: .codeBlock)
        let range = TextRange(start: DocumentPosition(blockIndex: 0, offset: 0), end: DocumentPosition(blockIndex: 0, offset: 2))
        let cmd = ApplyFormattingCommand(formatting: [.bold], to: range, operation: .apply, context: context)
        let result = cmd.execute(on: state)
        switch result {
        case .success(let s):
            XCTAssertFalse(s.currentFormatting.contains(.bold))
        case .failure:
            XCTAssertTrue(true)
        }
    }

    // MARK: - Document Service Parsing Edge Cases

    func testParseHeadingLevelsIncludingH6() {
        let md = "# h1\n\n###### h6"
        let parsed = documentService.parseMarkdown(md)
        XCTAssertEqual(parsed.blocks.count, 2)
        guard case .heading(let h1) = parsed.blocks[0], case .heading(let h6) = parsed.blocks[1] else { return XCTFail("expected headings") }
        XCTAssertEqual(h1.level, .h1)
        XCTAssertEqual(h6.level, .h6)
    }

    func testParseMixedLists() {
        let md = "- bullet 1\n- bullet 2\n\n1. number 1\n2. number 2"
        let parsed = documentService.parseMarkdown(md)
        XCTAssertEqual(parsed.blocks.count, 2)
        guard case .list(let bullets) = parsed.blocks[0], case .list(let numbers) = parsed.blocks[1] else { return XCTFail("expected lists") }
        XCTAssertEqual(bullets.items.count, 2)
        XCTAssertEqual(numbers.items.count, 2)
    }

    func testGenerateMarkdownRoundTrip() {
        let md = "## Title\n\n- A\n- B\n\n> Quote"
        let parsed = documentService.parseMarkdown(md)
        let out = documentService.generateMarkdown(from: parsed)
        // Parsing is lossy in whitespace; verify structural roundtrip
        let reparsed = documentService.parseMarkdown(out)
        XCTAssertEqual(parsed.blocks.count, reparsed.blocks.count)
    }

    func testValidationAllowsEmptyListItems() {
        let md = "- \n\n- "
        let parsed = documentService.parseMarkdown(md)
        XCTAssertEqual(parsed.blocks.count, 2)
        if case .list(let l1) = parsed.blocks[0] { XCTAssertEqual(l1.items.count, 1); XCTAssertEqual(l1.items[0].text, "") }
        if case .list(let l2) = parsed.blocks[1] { XCTAssertEqual(l2.items.count, 1); XCTAssertEqual(l2.items[0].text, "") }
        let result = documentService.validateDocument(md)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Position Validation & Errors

    func testSetBlockTypeInvalidPositionFails() {
        let state = MarkdownEditorState.withParagraph("Hello")
        let invalidPos = DocumentPosition(blockIndex: 5, offset: 0)
        let cmd = SetBlockTypeCommand(blockType: .heading(level: .h1), at: invalidPos, context: context)
        let result = cmd.execute(on: state)
        switch result {
        case .success:
            XCTFail("Should fail with invalid position")
        case .failure:
            XCTAssertTrue(true)
        }
    }

    func testInsertTextUnsupportedInList() {
        let state = MarkdownEditorState(content: "- Item", selection: TextRange(at: DocumentPosition(blockIndex: 0, offset: 2)), currentBlockType: .unorderedList)
        let cmd = InsertTextCommand(text: "X", at: state.selection.start, context: context)
        let result = cmd.execute(on: state)
        switch result {
        case .success:
            XCTFail("Insert into list should be unsupported in domain service")
        case .failure:
            XCTAssertTrue(true)
        }
    }

    func testDeleteTextUnsupportedInList() {
        let state = MarkdownEditorState(content: "- Item", selection: TextRange(start: DocumentPosition(blockIndex: 0, offset: 0), end: DocumentPosition(blockIndex: 0, offset: 1)), currentBlockType: .unorderedList)
        let cmd = DeleteTextCommand(range: state.selection, context: context)
        let result = cmd.execute(on: state)
        switch result {
        case .success:
            XCTFail("Delete in list should be unsupported in domain service")
        case .failure:
            XCTAssertTrue(true)
        }
    }

    // MARK: - State Service Semantics

    func testAreStatesEquivalentIgnoresMetadataAndUnsaved() {
        let a = MarkdownEditorState(content: "Hello", selection: TextRange(at: .start), currentFormatting: [], currentBlockType: .paragraph, hasUnsavedChanges: false, metadata: .default)
        let b = MarkdownEditorState(content: "Hello", selection: TextRange(at: .start), currentFormatting: [], currentBlockType: .paragraph, hasUnsavedChanges: true, metadata: DocumentMetadata(version: "2.0"))
        XCTAssertTrue(stateService.areStatesEquivalent(a, b))
    }

    func testUpdateSelectionRecomputesFormattingAndBlockType() {
        let state = MarkdownEditorState(content: "# Title", selection: TextRange(at: .start))
        let newRange = TextRange(at: DocumentPosition(blockIndex: 0, offset: 2))
        let result = stateService.updateSelection(to: newRange, in: state)
        switch result {
        case .success(let s):
            XCTAssertEqual(s.currentBlockType, .heading(level: .h1))
        case .failure(let e):
            XCTFail("Unexpected failure: \(e)")
        }
    }

    // MARK: - Command Builder & History

    func testCompositeReplaceText() {
        let state = MarkdownEditorState.withParagraph("Hello world")
        let range = TextRange(start: DocumentPosition(blockIndex: 0, offset: 6), end: DocumentPosition(blockIndex: 0, offset: 11))
        let builder = MarkdownCommandBuilder(context: context)
        let cmd = builder.replaceText(in: range, with: "planet")
        let result = cmd.execute(on: state)
        switch result {
        case .success(let s):
            XCTAssertEqual(s.content, "Hello planet")
        case .failure(let e):
            XCTFail("Unexpected failure: \(e)")
        }
    }

    func testHistoryUndoRedoSimpleInsert() {
        let history = MarkdownCommandHistory()
        let state = MarkdownEditorState.withParagraph("Hi")
        let insert = InsertTextCommand(text: "!", at: DocumentPosition(blockIndex: 0, offset: 2), context: context)
        guard case .success(let afterInsert) = history.execute(insert, on: state) else { return XCTFail("insert failed") }
        XCTAssertEqual(afterInsert.content, "Hi!")
        guard let undone = history.undo(on: afterInsert), case .success(let afterUndo) = undone else { return XCTFail("undo failed") }
        XCTAssertEqual(afterUndo.content, "Hi")
        guard let redone = history.redo(on: afterUndo), case .success(let afterRedo) = redone else { return XCTFail("redo failed") }
        XCTAssertEqual(afterRedo.content, "Hi!")
    }

    // MARK: - Stats & Validation

    func testDocumentStatsForMixedContent() {
        let md = "# Title\n\nPara\n\n- A\n- B\n\n```\ncode\n```\n\n> quote"
        let stats = documentService.getDocumentStats(md)
        XCTAssertEqual(stats.headingCount, 1)
        XCTAssertEqual(stats.paragraphCount, 1)
        XCTAssertEqual(stats.listCount, 1)
        XCTAssertEqual(stats.codeBlockCount, 1)
        XCTAssertEqual(stats.quoteCount, 1)
    }
} 