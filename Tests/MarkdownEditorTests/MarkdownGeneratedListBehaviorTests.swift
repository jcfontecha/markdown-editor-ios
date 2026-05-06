import XCTest
import Lexical
import LexicalListPlugin
@testable import MarkdownEditor

final class MarkdownGeneratedListBehaviorTests: MarkdownTestCase {
    func testGeneratedListImportMatrixCreatesStableLists() throws {
        let markers = ["-", "*", "+", "1.", "01.", "10."]
        let indents = ["", " ", "  ", "    "]
        let contents = [
            "plain",
            "**bold**",
            "*italic*",
            "~~strike~~",
            "`code`",
            "[link](https://example.com)",
            "emoji 👩🏽‍💻",
            "RTL שלום",
            "CJK 日本語",
            "combining e\u{301}",
            "escaped \\- marker",
            "url https://example.com/a/b?c=d"
        ]
        let lineEndings = ["\n", "\r\n", "\r"]

        var exercised = 0
        for marker in markers {
            for indent in indents {
                for content in contents {
                    for lineEnding in lineEndings {
                        let markdown = "\(indent)\(marker) \(content)\(lineEnding)\(indent)\(marker) second"
                        _ = markdownEditor.loadMarkdown(MarkdownDocument(content: markdown))

                        try editor.read {
                            let root = try XCTUnwrap(getRoot(), "missing root for \(markdown.debugDescription)")
                            XCTAssertTrue(
                                root.getChildren().contains { $0 is ListNode },
                                "expected list node for \(markdown.debugDescription)"
                            )
                        }

                        let exported = try XCTUnwrap(markdownEditor.exportMarkdown().value?.content)
                        XCTAssertFalse(exported.contains("\u{200B}"), markdown.debugDescription)
                        exercised += 1
                    }
                }
            }
        }

        XCTAssertGreaterThanOrEqual(exercised, 800)
    }

    func testGeneratedListEnterMatrixCreatesSiblingItems() throws {
        let cases: [(name: String, markdown: String, text: String, offset: Int)] = [
            ("unordered-end", "- first", "first", 5),
            ("unordered-middle", "- first", "first", 2),
            ("ordered-end", "1. first", "first", 5),
            ("ordered-middle", "1. first", "first", 2),
            ("unicode-end", "- 👩🏽‍💻 coder", "coder", 5),
            ("rtl-end", "- שלום", "שלום", 4)
        ]

        for testCase in cases {
            _ = markdownEditor.loadMarkdown(MarkdownDocument(content: testCase.markdown))
            try selectText(testCase.text, offset: testCase.offset)
            markdownEditor.textView.insertText("\n")

            try editor.read {
                let list = try XCTUnwrap(getRoot()?.getFirstChild() as? ListNode, testCase.name)
                XCTAssertEqual(list.getChildrenSize(), 2, testCase.name)
            }
        }
    }

    private func selectText(_ text: String, offset: Int) throws {
        try editor.update {
            guard let root = getRoot() else {
                XCTFail("Missing root")
                return
            }

            var target: TextNode?
            func visit(_ node: Node) {
                if target != nil { return }
                if let textNode = node as? TextNode, textNode.getTextContent().contains(text) {
                    target = textNode
                    return
                }
                if let element = node as? ElementNode {
                    element.getChildren().forEach(visit)
                }
            }
            visit(root)

            guard let target else {
                XCTFail("Missing text node containing \(text)")
                return
            }

            let point = Point(key: target.key, offset: offset, type: .text)
            getActiveEditorState()?.selection = RangeSelection(anchor: point, focus: point, format: TextFormat())
        }
    }
}
