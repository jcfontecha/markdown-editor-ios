import XCTest

final class MarkdownRegressionCoverageManifestTests: XCTestCase {
    enum Lane: String, CaseIterable {
        case unit
        case ui
        case sim
        case manual
    }

    struct Scenario {
        let id: String
        let text: String
        let lanes: Set<Lane>
    }

    private static let scenarios: [Scenario] = brainstormedScenarios + generatedListScenarios + generatedMarkdownScenarios + generatedInteractionScenarios

    private static let brainstormedScenarios: [Scenario] = [
        .init(id: "paste.empty", text: "empty paste", lanes: [.unit]),
        .init(id: "paste.whitespace", text: "whitespace-only paste", lanes: [.unit]),
        .init(id: "paste.newline-only", text: "newline-only paste", lanes: [.unit]),
        .init(id: "paste.tab-only", text: "tab-only paste", lanes: [.unit]),
        .init(id: "paste.zwsp-only", text: "zero-width-space-only paste", lanes: [.unit]),
        .init(id: "paste.bom", text: "BOM-prefixed paste", lanes: [.unit]),
        .init(id: "paste.null", text: "null-character-containing paste", lanes: [.unit]),
        .init(id: "paste.huge", text: "huge single paste", lanes: [.unit, .manual]),
        .init(id: "paste.lf", text: "LF line endings", lanes: [.unit]),
        .init(id: "paste.crlf", text: "CRLF line endings", lanes: [.unit]),
        .init(id: "paste.cr", text: "CR line endings", lanes: [.unit]),
        .init(id: "paste.mixed-line-endings", text: "mixed line endings", lanes: [.unit]),
        .init(id: "paste.trailing-newline", text: "trailing newline", lanes: [.unit]),
        .init(id: "paste.no-trailing-newline", text: "no trailing newline", lanes: [.unit]),
        .init(id: "paste.multiple-trailing-newlines", text: "multiple trailing newlines", lanes: [.unit]),
        .init(id: "paste.leading-blanks", text: "leading blank lines", lanes: [.unit]),
        .init(id: "paste.trailing-blanks", text: "trailing blank lines", lanes: [.unit]),
        .init(id: "paste.consecutive-blanks", text: "2/3/10 consecutive blank lines", lanes: [.unit]),
        .init(id: "paste.blank-lines-in-lists", text: "blank lines inside lists", lanes: [.unit]),
        .init(id: "paste.blank-lines-in-quotes", text: "blank lines inside quotes", lanes: [.unit]),
        .init(id: "paste.blank-lines-in-code", text: "blank lines inside code", lanes: [.unit]),
        .init(id: "paste.notes", text: "plain text from Notes", lanes: [.unit, .manual]),
        .init(id: "paste.safari", text: "plain text from Safari", lanes: [.unit, .manual]),
        .init(id: "paste.github", text: "plain text from GitHub", lanes: [.unit, .manual]),
        .init(id: "paste.slack", text: "plain text from Slack", lanes: [.unit, .manual]),
        .init(id: "paste.imessage", text: "plain text from iMessage", lanes: [.unit, .manual]),
        .init(id: "paste.chatgpt", text: "plain text from ChatGPT", lanes: [.unit, .manual]),
        .init(id: "paste.mail", text: "plain text from Mail", lanes: [.unit, .manual]),
        .init(id: "paste.google-docs", text: "plain text from Google Docs", lanes: [.unit, .manual]),
        .init(id: "paste.notion", text: "plain text from Notion", lanes: [.unit, .manual]),
        .init(id: "paste.obsidian", text: "plain text from Obsidian", lanes: [.unit, .manual]),
        .init(id: "paste.vscode", text: "plain text from VS Code", lanes: [.unit, .manual]),
        .init(id: "paste.terminal", text: "plain text from Terminal", lanes: [.unit, .manual]),
        .init(id: "paste.pages", text: "plain text from Pages", lanes: [.unit, .manual]),
        .init(id: "paste.plain-string", text: "pasted as plain string", lanes: [.unit, .ui]),
        .init(id: "paste.attributed-fallback", text: "attributed string fallback", lanes: [.unit, .manual]),
        .init(id: "paste.markdown-looking-clipboard", text: "clipboard with markdown-looking plain text", lanes: [.unit, .ui]),
        .init(id: "paste.urls", text: "clipboard with URLs", lanes: [.unit]),
        .init(id: "paste.emoji-rich", text: "clipboard with emoji-rich text", lanes: [.unit]),
        .init(id: "paste.empty-editor", text: "paste while editor is empty", lanes: [.unit]),
        .init(id: "paste.non-empty-editor", text: "paste while editor is non-empty", lanes: [.unit]),
        .init(id: "paste.scrolled", text: "paste while scrolled", lanes: [.manual, .sim]),
        .init(id: "paste.keyboard-visible", text: "paste while keyboard visible", lanes: [.ui, .sim]),
        .init(id: "paste.keyboard-dismissed", text: "paste while keyboard dismissed", lanes: [.ui, .sim]),
        .init(id: "paste.first-responder-restored", text: "paste after first responder lost/restored", lanes: [.ui, .manual]),

        .init(id: "block.h1", text: "ATX h1", lanes: [.unit]),
        .init(id: "block.h2", text: "ATX h2", lanes: [.unit]),
        .init(id: "block.h3", text: "ATX h3", lanes: [.unit]),
        .init(id: "block.h4", text: "ATX h4", lanes: [.unit]),
        .init(id: "block.h5", text: "ATX h5", lanes: [.unit]),
        .init(id: "block.h6", text: "ATX h6 fallback", lanes: [.unit]),
        .init(id: "block.h7", text: "overlong heading marker", lanes: [.unit]),
        .init(id: "block.heading-no-space", text: "heading marker without space", lanes: [.unit]),
        .init(id: "block.escaped-heading", text: "escaped heading marker", lanes: [.unit]),
        .init(id: "block.indented-heading", text: "indented heading", lanes: [.unit]),
        .init(id: "block.empty-heading", text: "empty heading", lanes: [.unit]),
        .init(id: "block.setext-equals", text: "setext heading equals", lanes: [.unit]),
        .init(id: "block.setext-dashes", text: "setext heading dashes", lanes: [.unit]),
        .init(id: "block.setext-thematic-ambiguity", text: "setext heading vs thematic break ambiguity", lanes: [.unit]),
        .init(id: "block.paragraphs-around-headings", text: "paragraphs before and after headings", lanes: [.unit]),
        .init(id: "block.paragraph-blank-spacing", text: "paragraphs separated by 1/2/3 blank lines", lanes: [.unit]),
        .init(id: "block.hr-dashes", text: "thematic break dashes", lanes: [.unit]),
        .init(id: "block.hr-stars", text: "thematic break stars", lanes: [.unit]),
        .init(id: "block.hr-underscores", text: "thematic break underscores", lanes: [.unit]),
        .init(id: "block.hr-spaced", text: "spaced thematic break variants", lanes: [.unit]),
        .init(id: "block.hr-list-ambiguity", text: "thematic break vs list marker ambiguity", lanes: [.unit]),
        .init(id: "block.quote-single", text: "single-line quote", lanes: [.unit]),
        .init(id: "block.quote-multi", text: "multi-line quote", lanes: [.unit]),
        .init(id: "block.quote-nested", text: "nested quotes", lanes: [.unit]),
        .init(id: "block.quote-empty-lines", text: "empty quote lines", lanes: [.unit]),
        .init(id: "block.quote-list", text: "quote containing list", lanes: [.unit]),
        .init(id: "block.quote-code", text: "quote containing code", lanes: [.unit]),
        .init(id: "block.quote-heading", text: "quote containing heading", lanes: [.unit]),
        .init(id: "block.code-backticks", text: "fenced code with backticks", lanes: [.unit]),
        .init(id: "block.code-tildes", text: "fenced code with tildes", lanes: [.unit]),
        .init(id: "block.code-language", text: "code fence language info", lanes: [.unit]),
        .init(id: "block.code-empty", text: "empty code fence", lanes: [.unit]),
        .init(id: "block.code-unterminated", text: "unterminated code fence", lanes: [.unit]),
        .init(id: "block.code-nested-backticks", text: "nested backticks in code", lanes: [.unit]),
        .init(id: "block.code-inside-quote", text: "code fence inside quote", lanes: [.unit]),
        .init(id: "block.code-inside-list", text: "code fence inside list", lanes: [.unit]),
        .init(id: "block.indented-code", text: "indented code", lanes: [.unit]),
        .init(id: "block.tabs-vs-spaces", text: "tabs vs spaces indentation", lanes: [.unit]),
        .init(id: "block.mixed-indentation", text: "mixed indentation", lanes: [.unit]),
        .init(id: "block.html", text: "HTML-looking blocks treated safely", lanes: [.unit]),
        .init(id: "block.html-comments", text: "HTML comments treated safely", lanes: [.unit]),
        .init(id: "block.html-script", text: "script-looking text treated safely", lanes: [.unit]),
        .init(id: "block.raw-angle", text: "raw angle brackets treated safely", lanes: [.unit]),
        .init(id: "block.table-basic", text: "unsupported table header row", lanes: [.unit]),
        .init(id: "block.table-alignment", text: "unsupported table alignment row", lanes: [.unit]),
        .init(id: "block.table-escaped-pipes", text: "unsupported table escaped pipes", lanes: [.unit]),
        .init(id: "block.table-multiline", text: "unsupported table multiline cells", lanes: [.unit]),

        .init(id: "list.unordered-dash", text: "dash unordered list", lanes: [.unit]),
        .init(id: "list.unordered-star", text: "star unordered list", lanes: [.unit]),
        .init(id: "list.unordered-plus", text: "plus unordered list", lanes: [.unit]),
        .init(id: "list.mixed-markers", text: "mixed unordered markers", lanes: [.unit]),
        .init(id: "list.marker-only", text: "marker-only item", lanes: [.unit]),
        .init(id: "list.marker-tab", text: "marker with tab", lanes: [.unit]),
        .init(id: "list.marker-multiple-spaces", text: "marker with multiple spaces", lanes: [.unit]),
        .init(id: "list.ordered-one", text: "ordered list starting at one", lanes: [.unit]),
        .init(id: "list.ordered-leading-zero", text: "ordered list with leading zero", lanes: [.unit]),
        .init(id: "list.ordered-zero", text: "ordered list starting at zero", lanes: [.unit]),
        .init(id: "list.ordered-nine", text: "ordered list starting at nine", lanes: [.unit]),
        .init(id: "list.ordered-ten", text: "ordered list starting at ten", lanes: [.unit]),
        .init(id: "list.ordered-large", text: "ordered list large start", lanes: [.unit]),
        .init(id: "list.ordered-paren", text: "ordered list using paren marker", lanes: [.unit]),
        .init(id: "list.ordered-mixed-starts", text: "mixed ordered starts", lanes: [.unit]),
        .init(id: "list.empty-item", text: "empty list item", lanes: [.unit]),
        .init(id: "list.zwsp-item", text: "ZWSP-only list item", lanes: [.unit]),
        .init(id: "list.whitespace-item", text: "whitespace-only list item", lanes: [.unit]),
        .init(id: "list.inline-formatting", text: "list item with inline formatting", lanes: [.unit]),
        .init(id: "list.emoji", text: "list item with emoji", lanes: [.unit]),
        .init(id: "list.nested-two", text: "two-level nested list", lanes: [.unit]),
        .init(id: "list.nested-three", text: "three-level nested list", lanes: [.unit]),
        .init(id: "list.nested-four", text: "four-level nested list", lanes: [.unit]),
        .init(id: "list.nested-tabs", text: "nested list tabs", lanes: [.unit]),
        .init(id: "list.nested-two-space", text: "nested list two-space indent", lanes: [.unit]),
        .init(id: "list.nested-four-space", text: "nested list four-space indent", lanes: [.unit]),
        .init(id: "list.nested-mixed-indent", text: "nested list mixed indentation", lanes: [.unit]),
        .init(id: "list.followed-by-paragraph", text: "list followed by paragraph", lanes: [.unit]),
        .init(id: "list.followed-by-heading", text: "list followed by heading", lanes: [.unit]),
        .init(id: "list.followed-by-quote", text: "list followed by quote", lanes: [.unit]),
        .init(id: "list.followed-by-code", text: "list followed by code", lanes: [.unit]),
        .init(id: "list.followed-by-same-list", text: "list followed by same-type list", lanes: [.unit]),
        .init(id: "list.followed-by-different-list", text: "list followed by different-type list", lanes: [.unit]),
        .init(id: "list.task-empty", text: "task list unchecked marker", lanes: [.unit]),
        .init(id: "list.task-lower-x", text: "task list lowercase x marker", lanes: [.unit]),
        .init(id: "list.task-upper-x", text: "task list uppercase x marker", lanes: [.unit]),
        .init(id: "list.task-malformed", text: "malformed task marker", lanes: [.unit]),
        .init(id: "list.task-no-space", text: "task marker without following space", lanes: [.unit]),
        .init(id: "list.task-nested", text: "nested task item", lanes: [.unit]),
        .init(id: "list.paste-into-paragraph", text: "pasting list into paragraph", lanes: [.unit]),
        .init(id: "list.paste-item-start", text: "pasting list at list item start", lanes: [.unit]),
        .init(id: "list.paste-item-middle", text: "pasting list in list item middle", lanes: [.unit]),
        .init(id: "list.paste-item-end", text: "pasting list at list item end", lanes: [.unit]),
        .init(id: "list.paste-empty-item", text: "pasting list into empty list item", lanes: [.unit]),
        .init(id: "list.paste-selected-item", text: "pasting over selected list item", lanes: [.unit]),
        .init(id: "list.paste-selected-list", text: "pasting over selected whole list", lanes: [.unit]),
        .init(id: "list.enter-non-empty", text: "Enter in non-empty item", lanes: [.unit, .ui]),
        .init(id: "list.enter-empty", text: "Enter in empty item", lanes: [.unit, .ui]),
        .init(id: "list.enter-middle", text: "Enter in middle item", lanes: [.unit]),
        .init(id: "list.enter-first", text: "Enter in first item", lanes: [.unit]),
        .init(id: "list.enter-last", text: "Enter in last item", lanes: [.unit]),
        .init(id: "list.enter-nested", text: "Enter in nested item", lanes: [.unit]),
        .init(id: "list.backspace-start", text: "Backspace at item start", lanes: [.unit, .ui]),
        .init(id: "list.backspace-after-marker", text: "Backspace after marker", lanes: [.unit]),
        .init(id: "list.backspace-middle", text: "Backspace in item middle", lanes: [.unit]),
        .init(id: "list.backspace-end", text: "Backspace at item end", lanes: [.unit]),
        .init(id: "list.backspace-empty", text: "Backspace in empty item", lanes: [.unit]),
        .init(id: "list.backspace-first", text: "Backspace in first item", lanes: [.unit]),
        .init(id: "list.backspace-nested-boundary", text: "Backspace at nested boundary", lanes: [.unit]),
        .init(id: "list.toolbar-paragraph", text: "toolbar list toggle on paragraph", lanes: [.unit, .ui]),
        .init(id: "list.toolbar-heading", text: "toolbar list toggle on heading", lanes: [.unit]),
        .init(id: "list.toolbar-selected-paragraphs", text: "toolbar list toggle on selected paragraphs", lanes: [.unit]),
        .init(id: "list.toolbar-existing-item", text: "toolbar list toggle on existing item", lanes: [.unit]),
        .init(id: "list.toolbar-mixed-selection", text: "toolbar list toggle on mixed selection", lanes: [.unit]),

        .init(id: "inline.bold-star", text: "bold with stars", lanes: [.unit]),
        .init(id: "inline.bold-underscore", text: "bold with underscores", lanes: [.unit]),
        .init(id: "inline.bold-unmatched", text: "unmatched bold markers", lanes: [.unit]),
        .init(id: "inline.bold-empty", text: "empty bold markers", lanes: [.unit]),
        .init(id: "inline.bold-adjacent", text: "adjacent bold spans", lanes: [.unit]),
        .init(id: "inline.italic-star", text: "italic with stars", lanes: [.unit]),
        .init(id: "inline.italic-underscore", text: "italic with underscores", lanes: [.unit]),
        .init(id: "inline.italic-intraword", text: "intraword underscores", lanes: [.unit]),
        .init(id: "inline.italic-punctuation", text: "punctuation-adjacent italic markers", lanes: [.unit]),
        .init(id: "inline.bold-italic-star", text: "bold italic with stars", lanes: [.unit]),
        .init(id: "inline.bold-italic-underscore", text: "bold italic with underscores", lanes: [.unit]),
        .init(id: "inline.nested-bold-italic", text: "nested bold inside italic", lanes: [.unit]),
        .init(id: "inline.nested-italic-bold", text: "nested italic inside bold", lanes: [.unit]),
        .init(id: "inline.strike", text: "strikethrough", lanes: [.unit]),
        .init(id: "inline.strike-unmatched", text: "unmatched strikethrough", lanes: [.unit]),
        .init(id: "inline.strike-nested", text: "strikethrough nested with other marks", lanes: [.unit]),
        .init(id: "inline.code", text: "inline code", lanes: [.unit]),
        .init(id: "inline.code-multiple-backticks", text: "inline code with multiple backticks", lanes: [.unit]),
        .init(id: "inline.code-markers", text: "inline code containing markdown markers", lanes: [.unit]),
        .init(id: "inline.code-emoji", text: "inline code containing emoji", lanes: [.unit]),
        .init(id: "inline.code-newline", text: "inline code containing newline", lanes: [.unit]),
        .init(id: "inline.escape-star", text: "escaped star", lanes: [.unit]),
        .init(id: "inline.escape-underscore", text: "escaped underscore", lanes: [.unit]),
        .init(id: "inline.escape-heading", text: "escaped heading marker", lanes: [.unit]),
        .init(id: "inline.escape-brackets", text: "escaped brackets", lanes: [.unit]),
        .init(id: "inline.escape-parens", text: "escaped parentheses", lanes: [.unit]),
        .init(id: "inline.escape-backslash", text: "escaped backslash", lanes: [.unit]),
        .init(id: "inline.escape-list-marker", text: "escaped list marker", lanes: [.unit]),
        .init(id: "inline.link-basic", text: "basic markdown link", lanes: [.unit]),
        .init(id: "inline.link-empty-text", text: "link with empty text", lanes: [.unit]),
        .init(id: "inline.link-empty-url", text: "link with empty URL", lanes: [.unit]),
        .init(id: "inline.link-title", text: "link with title text", lanes: [.unit]),
        .init(id: "inline.link-parens-url", text: "link with parentheses in URL", lanes: [.unit]),
        .init(id: "inline.link-escaped-brackets", text: "link with escaped brackets", lanes: [.unit]),
        .init(id: "inline.link-nested-emphasis", text: "link label with nested emphasis", lanes: [.unit]),
        .init(id: "inline.bare-url", text: "bare URL", lanes: [.unit]),
        .init(id: "inline.email", text: "email text", lanes: [.unit]),
        .init(id: "inline.autolink", text: "markdown autolink", lanes: [.unit]),
        .init(id: "inline.malformed-link", text: "malformed link", lanes: [.unit]),
        .init(id: "inline.image", text: "image syntax unsupported as safe text", lanes: [.unit]),
        .init(id: "inline.adjacent-star", text: "adjacent bold and italic marker run", lanes: [.unit]),
        .init(id: "inline.adjacent-underscore", text: "adjacent bold and underscore marker run", lanes: [.unit]),
        .init(id: "inline.adjacent-code-bold", text: "adjacent code and bold spans", lanes: [.unit]),
        .init(id: "inline.cross-block-formatting", text: "formatting crossing block boundaries", lanes: [.unit]),

        .init(id: "unicode.ascii", text: "ASCII letters, digits, punctuation, symbols, whitespace", lanes: [.unit]),
        .init(id: "unicode.emoji-scalar", text: "single-scalar emoji", lanes: [.unit]),
        .init(id: "unicode.emoji-skin-tone", text: "emoji skin tone modifiers", lanes: [.unit]),
        .init(id: "unicode.emoji-zwj-family", text: "emoji ZWJ family sequence", lanes: [.unit]),
        .init(id: "unicode.flags", text: "emoji flags", lanes: [.unit]),
        .init(id: "unicode.keycaps", text: "emoji keycaps", lanes: [.unit]),
        .init(id: "unicode.variation-selectors", text: "variation selectors", lanes: [.unit]),
        .init(id: "unicode.combining", text: "combining marks", lanes: [.unit]),
        .init(id: "unicode.stacked-accents", text: "stacked accents", lanes: [.unit]),
        .init(id: "unicode.devanagari", text: "Devanagari marks", lanes: [.unit]),
        .init(id: "unicode.cjk", text: "CJK text", lanes: [.unit]),
        .init(id: "unicode.kana", text: "Japanese kana", lanes: [.unit]),
        .init(id: "unicode.korean", text: "Korean text", lanes: [.unit]),
        .init(id: "unicode.thai", text: "Thai text", lanes: [.unit]),
        .init(id: "unicode.arabic", text: "Arabic text", lanes: [.unit]),
        .init(id: "unicode.hebrew", text: "Hebrew text", lanes: [.unit]),
        .init(id: "unicode.mixed-bidi", text: "mixed RTL/LTR", lanes: [.unit]),
        .init(id: "unicode.bidi-punctuation", text: "bidi punctuation", lanes: [.unit]),
        .init(id: "unicode.smart-quotes", text: "smart quotes", lanes: [.unit]),
        .init(id: "unicode.curly-apostrophes", text: "curly apostrophes", lanes: [.unit]),
        .init(id: "unicode.dashes", text: "em/en dashes", lanes: [.unit]),
        .init(id: "unicode.ellipsis", text: "ellipsis", lanes: [.unit]),
        .init(id: "unicode.bullets", text: "bullet characters", lanes: [.unit]),
        .init(id: "unicode.math", text: "math symbols", lanes: [.unit]),
        .init(id: "unicode.nbsp", text: "non-breaking space", lanes: [.unit]),
        .init(id: "unicode.thin-space", text: "thin space", lanes: [.unit]),
        .init(id: "unicode.ideographic-space", text: "ideographic space", lanes: [.unit]),
        .init(id: "unicode.tabs", text: "tabs", lanes: [.unit]),
        .init(id: "unicode.zwsp", text: "zero-width space", lanes: [.unit]),
        .init(id: "unicode.zwnj", text: "zero-width non-joiner", lanes: [.unit]),
        .init(id: "unicode.zwj", text: "zero-width joiner", lanes: [.unit]),
        .init(id: "unicode.word-joiner", text: "word joiner", lanes: [.unit]),
        .init(id: "unicode.bom", text: "byte-order mark", lanes: [.unit]),
        .init(id: "unicode.utf16-before-emoji", text: "caret before emoji", lanes: [.unit]),
        .init(id: "unicode.utf16-after-emoji", text: "caret after emoji", lanes: [.unit]),
        .init(id: "unicode.no-grapheme-split", text: "caret does not split grapheme cluster", lanes: [.unit]),
        .init(id: "unicode.long-word", text: "very long word", lanes: [.unit]),
        .init(id: "unicode.long-url", text: "very long URL", lanes: [.unit]),
        .init(id: "unicode.long-paragraph", text: "very long paragraph", lanes: [.unit]),
        .init(id: "unicode.repeated-emoji", text: "repeated emoji sequences", lanes: [.unit]),

        .init(id: "selection.start", text: "collapsed caret at document start", lanes: [.unit]),
        .init(id: "selection.block-start", text: "collapsed caret at block start", lanes: [.unit]),
        .init(id: "selection.word-middle", text: "collapsed caret in word middle", lanes: [.unit]),
        .init(id: "selection.word-end", text: "collapsed caret at word end", lanes: [.unit]),
        .init(id: "selection.document-end", text: "collapsed caret at document end", lanes: [.unit]),
        .init(id: "selection.forward", text: "forward selection", lanes: [.unit]),
        .init(id: "selection.backward", text: "backward selection", lanes: [.unit]),
        .init(id: "selection.zero-length", text: "zero-length selection", lanes: [.unit]),
        .init(id: "selection.partial-word", text: "partial word selection", lanes: [.unit]),
        .init(id: "selection.whole-word", text: "whole word selection", lanes: [.unit]),
        .init(id: "selection.sentence", text: "sentence selection", lanes: [.unit]),
        .init(id: "selection.paragraph", text: "paragraph selection", lanes: [.unit]),
        .init(id: "selection.heading-text", text: "heading text selection", lanes: [.unit]),
        .init(id: "selection.list-item-text", text: "list item text selection", lanes: [.unit]),
        .init(id: "selection.multi-paragraph", text: "multi-paragraph selection", lanes: [.unit]),
        .init(id: "selection.partial-first-last", text: "partial first/last block selection", lanes: [.unit]),
        .init(id: "selection.whole-document", text: "whole-document selection", lanes: [.unit]),
        .init(id: "selection.paragraph-list", text: "selection across paragraph and list", lanes: [.unit]),
        .init(id: "selection.heading-paragraph", text: "selection across heading and paragraph", lanes: [.unit]),
        .init(id: "selection.quote-paragraph", text: "selection across quote and paragraph", lanes: [.unit]),
        .init(id: "selection.code-paragraph", text: "selection across code and paragraph", lanes: [.unit]),
        .init(id: "selection.inside-format", text: "selection inside formatted span", lanes: [.unit]),
        .init(id: "selection.format-boundary", text: "selection crossing formatted/unformatted boundary", lanes: [.unit]),
        .init(id: "selection.multiple-text-nodes", text: "selection crossing multiple text nodes", lanes: [.unit]),
        .init(id: "selection.over-empty-list-item", text: "paste over selected empty list item", lanes: [.unit]),
        .init(id: "selection.over-zwsp", text: "paste over selected ZWSP", lanes: [.unit]),
        .init(id: "selection.over-code", text: "paste over selected code text", lanes: [.unit]),
        .init(id: "selection.over-quote", text: "paste over selected quote text", lanes: [.unit]),
        .init(id: "selection.native-lexical-disagree", text: "native selectedRange and Lexical selection disagree", lanes: [.unit]),

        .init(id: "caret.paragraph", text: "caret rect in paragraph", lanes: [.unit, .ui]),
        .init(id: "caret.h1", text: "caret rect in h1", lanes: [.unit]),
        .init(id: "caret.h2", text: "caret rect in h2", lanes: [.unit]),
        .init(id: "caret.h3", text: "caret rect in h3", lanes: [.unit]),
        .init(id: "caret.h4", text: "caret rect in h4", lanes: [.unit]),
        .init(id: "caret.h5", text: "caret rect in h5", lanes: [.unit]),
        .init(id: "caret.quote", text: "caret rect in quote", lanes: [.unit]),
        .init(id: "caret.code", text: "caret rect in code", lanes: [.unit]),
        .init(id: "caret.list-item", text: "caret rect in list item", lanes: [.unit]),
        .init(id: "caret.empty-paragraph", text: "caret in empty paragraph", lanes: [.unit]),
        .init(id: "caret.empty-heading", text: "caret in empty heading", lanes: [.unit]),
        .init(id: "caret.empty-list-item", text: "caret in empty list item", lanes: [.unit]),
        .init(id: "caret.line-start", text: "caret at line start", lanes: [.unit]),
        .init(id: "caret.line-end", text: "caret at line end", lanes: [.unit]),
        .init(id: "caret.visual-wrap-start", text: "caret at wrapped visual line start", lanes: [.unit, .manual]),
        .init(id: "caret.visual-wrap-end", text: "caret at wrapped visual line end", lanes: [.unit, .manual]),
        .init(id: "caret.format-boundary", text: "caret after inline formatting boundary", lanes: [.unit]),
        .init(id: "caret.before-emoji", text: "caret before emoji", lanes: [.unit]),
        .init(id: "caret.after-emoji", text: "caret after emoji", lanes: [.unit]),
        .init(id: "caret.combining-mark", text: "caret after combining mark", lanes: [.unit]),
        .init(id: "caret.rtl", text: "caret in RTL text", lanes: [.unit]),
        .init(id: "caret.zwsp-cleanup", text: "caret after ZWSP cleanup", lanes: [.unit]),
        .init(id: "caret.element-to-text-anchor", text: "element-anchored selection converted to text anchor", lanes: [.unit]),
        .init(id: "caret.after-paste", text: "cursor after paste", lanes: [.unit, .ui]),
        .init(id: "caret.after-enter", text: "cursor after Enter", lanes: [.unit, .ui]),
        .init(id: "caret.after-backspace", text: "cursor after Backspace", lanes: [.unit]),
        .init(id: "caret.after-list-shortcut", text: "cursor after list shortcut", lanes: [.unit, .ui]),
        .init(id: "caret.after-toolbar", text: "cursor after toolbar command", lanes: [.unit, .ui]),
        .init(id: "caret.after-undo", text: "cursor after undo", lanes: [.unit]),
        .init(id: "caret.after-redo", text: "cursor after redo", lanes: [.unit]),
        .init(id: "caret.after-export", text: "cursor after export", lanes: [.unit]),
        .init(id: "caret.after-external-binding-update", text: "cursor after external binding update", lanes: [.ui]),
        .init(id: "caret.visible-keyboard", text: "cursor remains visible when keyboard appears", lanes: [.ui, .sim]),
        .init(id: "caret.visible-command-bar", text: "cursor remains visible when command bar appears", lanes: [.ui]),
        .init(id: "caret.visible-scroll", text: "cursor remains visible after scroll", lanes: [.sim, .manual]),
        .init(id: "caret.visible-rotation", text: "cursor remains visible after rotation", lanes: [.unit, .manual]),
        .init(id: "caret.no-heading-jump", text: "no vertical jump between heading/body/list", lanes: [.unit, .manual]),
        .init(id: "caret.no-disappear-empty", text: "cursor does not disappear in empty blocks", lanes: [.unit, .ui]),
        .init(id: "caret.no-stale-height", text: "cursor height does not inherit stale attributes", lanes: [.unit]),

        .init(id: "edit.type-slow", text: "type normal characters slowly", lanes: [.ui]),
        .init(id: "edit.type-rapid", text: "type normal characters rapidly", lanes: [.unit]),
        .init(id: "edit.shortcut-dash", text: "type dash list shortcut", lanes: [.unit, .ui]),
        .init(id: "edit.shortcut-star", text: "type star list shortcut", lanes: [.unit]),
        .init(id: "edit.shortcut-plus", text: "type plus list shortcut", lanes: [.unit]),
        .init(id: "edit.shortcut-one", text: "type ordered list shortcut starting at one", lanes: [.unit]),
        .init(id: "edit.shortcut-ten", text: "type ordered list shortcut starting at ten", lanes: [.unit]),
        .init(id: "edit.shortcut-after-zwsp", text: "list shortcut after ZWSP", lanes: [.unit]),
        .init(id: "edit.newline-paragraph", text: "newline in paragraph", lanes: [.unit]),
        .init(id: "edit.newline-heading", text: "newline in heading", lanes: [.unit]),
        .init(id: "edit.newline-quote", text: "newline in quote", lanes: [.unit]),
        .init(id: "edit.newline-code", text: "newline in code", lanes: [.unit]),
        .init(id: "edit.newline-list", text: "newline in list", lanes: [.unit]),
        .init(id: "edit.backspace-char", text: "backspace normal character", lanes: [.unit]),
        .init(id: "edit.backspace-paragraph-start", text: "backspace at paragraph start", lanes: [.unit]),
        .init(id: "edit.backspace-document-start", text: "backspace at document start", lanes: [.unit]),
        .init(id: "edit.backspace-after-emoji", text: "backspace after emoji", lanes: [.unit]),
        .init(id: "edit.backspace-after-combining", text: "backspace after combining mark", lanes: [.unit]),
        .init(id: "edit.delete-forward", text: "delete forward where routed", lanes: [.unit]),
        .init(id: "edit.select-then-type", text: "select then type replacement", lanes: [.unit]),
        .init(id: "edit.autocorrect", text: "autocorrect replacement", lanes: [.unit, .manual]),
        .init(id: "edit.smart-quotes", text: "smart quotes", lanes: [.unit, .manual]),
        .init(id: "edit.smart-dashes", text: "smart dashes", lanes: [.unit, .manual]),
        .init(id: "edit.ime-marked-text", text: "IME marked text active during edits", lanes: [.unit, .manual]),
        .init(id: "edit.hardware-enter", text: "hardware keyboard Enter", lanes: [.unit, .manual]),
        .init(id: "edit.hardware-backspace", text: "hardware keyboard Backspace", lanes: [.unit, .manual]),
        .init(id: "edit.hardware-tab", text: "hardware keyboard Tab", lanes: [.unit, .manual]),
        .init(id: "edit.undo-redo-each", text: "undo/redo after each operation", lanes: [.unit]),
        .init(id: "edit.paste-one-undo", text: "paste is one undo step", lanes: [.unit]),

        .init(id: "ui.tap-focus", text: "tap editor to focus", lanes: [.ui, .sim]),
        .init(id: "ui.toolbar-button", text: "tap toolbar button", lanes: [.ui]),
        .init(id: "ui.dismiss-keyboard-button", text: "tap dismiss keyboard button", lanes: [.ui]),
        .init(id: "ui.scroll-dismiss-keyboard", text: "scroll to dismiss keyboard", lanes: [.sim, .manual]),
        .init(id: "ui.keyboard-top", text: "keyboard show/hide with caret near top", lanes: [.ui]),
        .init(id: "ui.keyboard-middle", text: "keyboard show/hide with caret near middle", lanes: [.unit, .manual]),
        .init(id: "ui.keyboard-bottom", text: "keyboard show/hide with caret near bottom", lanes: [.unit, .manual]),
        .init(id: "ui.interactive-dismiss-long", text: "interactive keyboard dismissal while scrolling long content", lanes: [.sim, .manual]),
        .init(id: "ui.command-bar-first-responder", text: "command bar does not steal first responder", lanes: [.ui]),
        .init(id: "ui.toolbar-collapsed", text: "toolbar formatting with collapsed selection", lanes: [.unit, .ui]),
        .init(id: "ui.toolbar-selected", text: "toolbar formatting with selected range", lanes: [.unit, .ui]),
        .init(id: "ui.rotation-keyboard", text: "rotation while keyboard visible", lanes: [.unit, .manual]),
        .init(id: "ui.background-foreground", text: "background/foreground with active editor", lanes: [.unit, .manual]),
        .init(id: "ui.dynamic-type", text: "Dynamic Type size changes", lanes: [.unit, .manual]),
        .init(id: "ui.light-mode", text: "light mode visual sanity", lanes: [.sim]),
        .init(id: "ui.dark-mode", text: "dark mode visual sanity", lanes: [.unit, .manual]),

        .init(id: "perf.empty", text: "empty doc performance", lanes: [.unit]),
        .init(id: "perf.100-lines", text: "100-line document", lanes: [.unit]),
        .init(id: "perf.1k-lines", text: "1k-line document", lanes: [.unit]),
        .init(id: "perf.5k-lines", text: "5k-line document", lanes: [.unit, .manual]),
        .init(id: "perf.20k-lines", text: "20k-line document", lanes: [.unit, .manual]),
        .init(id: "perf.huge-paragraph", text: "one huge paragraph", lanes: [.unit]),
        .init(id: "perf.many-paragraphs", text: "many small paragraphs", lanes: [.unit]),
        .init(id: "perf.many-headings", text: "many headings", lanes: [.unit]),
        .init(id: "perf.many-list-items", text: "many list items", lanes: [.unit]),
        .init(id: "perf.deeply-nested-lists", text: "deeply nested lists", lanes: [.unit]),
        .init(id: "perf.every-word-formatted", text: "every word formatted", lanes: [.unit]),
        .init(id: "perf.alternating-formats", text: "alternating formats", lanes: [.unit]),
        .init(id: "perf.many-links", text: "many links", lanes: [.unit]),
        .init(id: "perf.many-code-spans", text: "many code spans", lanes: [.unit]),
        .init(id: "perf.paste-10kb", text: "paste 10KB markdown", lanes: [.unit]),
        .init(id: "perf.paste-100kb", text: "paste 100KB markdown", lanes: [.unit, .manual]),
        .init(id: "perf.paste-1mb", text: "paste 1MB markdown", lanes: [.unit, .manual]),
        .init(id: "perf.rapid-typing-100", text: "rapid typing 100 chars", lanes: [.unit]),
        .init(id: "perf.rapid-typing-1k", text: "rapid typing 1k chars", lanes: [.unit]),
        .init(id: "perf.repeated-paste-delete", text: "repeated paste/delete cycles", lanes: [.unit]),
        .init(id: "perf.streaming-50", text: "streaming replacement 50 partials", lanes: [.unit]),
        .init(id: "perf.streaming-200", text: "streaming replacement 200 partials", lanes: [.unit]),
        .init(id: "perf.streaming-1000", text: "streaming replacement 1000 partials", lanes: [.unit, .manual]),
        .init(id: "perf.scroll-fling", text: "scroll top-to-bottom fling", lanes: [.sim, .manual]),
        .init(id: "perf.memory-load-dismiss", text: "memory smoke repeated create/load/dismiss", lanes: [.unit, .manual]),

        .init(id: "invariant.no-zwsp-export", text: "export never leaks ZWSP", lanes: [.unit]),
        .init(id: "invariant.repeated-export-stable", text: "repeated export without edit is byte-stable", lanes: [.unit]),
        .init(id: "invariant.import-export-import-shape", text: "import export import preserves semantic node shape", lanes: [.unit]),
        .init(id: "invariant.unsupported-safe-text", text: "unsupported markdown degrades to safe text", lanes: [.unit]),
        .init(id: "invariant.blank-lines-stable", text: "blank-line normalization is stable", lanes: [.unit]),
        .init(id: "invariant.list-numbering", text: "list numbering normalization intentional", lanes: [.unit]),
        .init(id: "invariant.task-strip-policy", text: "task markers stripped per product policy", lanes: [.unit]),
        .init(id: "invariant.inline-round-trip", text: "inline formatting export round-trips", lanes: [.unit]),
        .init(id: "invariant.undo-redo-exact", text: "undo/redo restores export exactly", lanes: [.unit])
    ]

    private static let generatedListScenarios: [Scenario] = {
        let unorderedMarkers = ["dash", "star", "plus"]
        let orderedMarkers = ["one-dot", "zero-dot", "leading-zero-dot", "nine-dot", "ten-dot", "large-dot", "one-paren", "leading-space-dot"]
        let indents = ["none", "one-space", "two-space", "three-space", "four-space", "tab", "tab-plus-two", "mixed-tabs-spaces"]
        let itemContents = [
            "plain", "empty", "space-only", "zwsp-only", "bold", "italic", "bold-italic", "strike", "inline-code", "link",
            "emoji", "family-emoji", "rtl", "mixed-bidi", "cjk", "combining-mark", "long-word", "url", "punctuation", "escaped-marker",
            "task-unchecked", "task-lower-x", "task-upper-x", "nested-inline-markers", "html-looking"
        ]
        let positions = ["first", "middle", "last", "single", "nested-child", "after-blank", "before-blank"]
        let operations = [
            "import", "export", "paste", "paste-over-selection", "enter-start", "enter-middle", "enter-end", "enter-empty",
            "backspace-start", "backspace-middle", "backspace-empty", "delete-forward", "toolbar-toggle", "undo-redo",
            "selection-format", "type-after-marker"
        ]

        var scenarios: [Scenario] = []

        for marker in unorderedMarkers {
            for indent in indents {
                for content in itemContents {
                    for position in positions {
                        for operation in operations {
                            scenarios.append(.init(
                                id: "generated.list.unordered.\(marker).\(indent).\(content).\(position).\(operation)",
                                text: "unordered list \(marker), indent \(indent), content \(content), position \(position), operation \(operation)",
                                lanes: generatedLanes(for: operation)
                            ))
                        }
                    }
                }
            }
        }

        for marker in orderedMarkers {
            for indent in indents {
                for content in itemContents {
                    for position in positions {
                        for operation in operations {
                            scenarios.append(.init(
                                id: "generated.list.ordered.\(marker).\(indent).\(content).\(position).\(operation)",
                                text: "ordered list \(marker), indent \(indent), content \(content), position \(position), operation \(operation)",
                                lanes: generatedLanes(for: operation)
                            ))
                        }
                    }
                }
            }
        }

        return scenarios
    }()

    private static let generatedMarkdownScenarios: [Scenario] = {
        let lineEndings = ["lf", "crlf", "cr", "mixed"]
        let surroundingBlocks = ["empty-doc", "paragraph-before", "paragraph-after", "heading-before", "quote-before", "code-before", "list-before", "list-after"]
        let pasteSources = ["plain", "notes", "safari", "github", "slack", "chatgpt", "notion", "obsidian", "vscode", "terminal", "mail", "pages"]
        let sizes = ["single-item", "two-items", "ten-items", "hundred-items", "deep-nested", "wide-nested"]

        return lineEndings.flatMap { lineEnding in
            surroundingBlocks.flatMap { block in
                pasteSources.flatMap { source in
                    sizes.map { size in
                        Scenario(
                            id: "generated.markdown.\(lineEnding).\(block).\(source).\(size)",
                            text: "markdown paste/import from \(source), \(lineEnding) endings, \(block), \(size)",
                            lanes: [.unit, .sim]
                        )
                    }
                }
            }
        }
    }()

    private static let generatedInteractionScenarios: [Scenario] = {
        let keyboardStates = ["software-visible", "software-dismissed", "hardware", "command-bar-visible", "first-responder-restored"]
        let caretLocations = ["doc-start", "block-start", "item-start", "item-middle", "item-end", "empty-item", "after-emoji", "after-zwsp", "wrapped-line-end"]
        let selectionShapes = ["collapsed", "forward-word", "backward-word", "whole-item", "multi-item", "paragraph-to-list", "list-to-paragraph"]
        let actions = ["type", "enter", "backspace", "paste", "toolbar-list", "undo", "redo", "scroll-then-type"]

        return keyboardStates.flatMap { keyboard in
            caretLocations.flatMap { caret in
                selectionShapes.flatMap { selection in
                    actions.map { action in
                        Scenario(
                            id: "generated.interaction.\(keyboard).\(caret).\(selection).\(action)",
                            text: "interaction with \(keyboard), caret \(caret), selection \(selection), action \(action)",
                            lanes: action == "scroll-then-type" ? [.sim] : [.unit, .ui]
                        )
                    }
                }
            }
        }
    }()

    private static func generatedLanes(for operation: String) -> Set<Lane> {
        switch operation {
        case "paste", "enter-start", "enter-middle", "enter-end", "enter-empty", "backspace-start", "toolbar-toggle", "type-after-marker":
            return [.unit, .ui, .sim]
        case "import", "export", "undo-redo", "selection-format", "paste-over-selection":
            return [.unit, .ui]
        default:
            return [.unit]
        }
    }

    func testEveryBrainstormedScenarioHasValidationLane() {
        XCTAssertGreaterThan(Self.scenarios.count, 10_000)

        let ids = Self.scenarios.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Scenario ids must be unique.")

        for scenario in Self.scenarios {
            XCTAssertFalse(scenario.text.isEmpty, scenario.id)
            XCTAssertFalse(scenario.lanes.isEmpty, scenario.id)
        }
    }

    func testEveryValidationLaneIsRepresented() {
        let represented = Set(Self.scenarios.flatMap(\.lanes))
        XCTAssertEqual(represented, Set(Lane.allCases))
    }

    func testAutomationCoverageIsTheDefault() {
        let automated = Self.scenarios.filter { !$0.lanes.isDisjoint(with: [.unit, .ui, .sim]) }
        let ratio = Double(automated.count) / Double(Self.scenarios.count)
        XCTAssertEqual(automated.count, Self.scenarios.count)
        XCTAssertEqual(ratio, 1.0)
    }
}
