import Foundation
import MarkdownEditor

@MainActor
final class MarkdownEditorAIEditBridge: ObservableObject, @unchecked Sendable {
    private weak var editor: MarkdownEditorView?

    private var toolInputBuffers: [String: String] = [:]
    private var activeToolCallID: String?
    private var activeReplacementSession: ReplacementSession?

    @Published var lastErrorDescription: String?

    func attachEditor(_ editor: MarkdownEditorView) {
        self.editor = editor
    }

    func detachEditor(_ editor: MarkdownEditorView) {
        if self.editor === editor {
            self.editor = nil
        }
    }

    func exportMarkdown() -> String? {
        guard let editor else { return nil }
        switch editor.exportMarkdown() {
        case .success(let document):
            return document.content
        case .failure(let error):
            lastErrorDescription = error.localizedDescription
            return nil
        }
    }

    func toolInputStarted(toolCallID: String) {
        toolInputBuffers[toolCallID] = ""
    }

    func toolInputDelta(toolCallID: String, delta: String) {
        toolInputBuffers[toolCallID, default: ""].append(delta)

        guard let input = toolInputBuffers[toolCallID] else { return }

        // For streamed JSON tool input, wait for complete (terminated) strings before we act on match targeting.
        // `replaceText` should update even while unterminated to enable live editor updates.
        let findText = JSONToolInputExtractor.extractStringValue(key: "findText", from: input, allowPartial: false)
        let beforeContext = JSONToolInputExtractor.extractStringValue(key: "beforeContext", from: input, allowPartial: false)
        let afterContext = JSONToolInputExtractor.extractStringValue(key: "afterContext", from: input, allowPartial: false)
        let replaceText = JSONToolInputExtractor.extractStringValue(key: "replaceText", from: input, allowPartial: true) ?? ""

        if activeToolCallID != toolCallID {
            // New tool call streaming in. Cancel any prior session and start fresh.
            activeReplacementSession?.cancel()
            activeReplacementSession = nil
            activeToolCallID = toolCallID
        }

        guard activeReplacementSession == nil else {
            activeReplacementSession?.setText(replaceText)
            return
        }

        guard let findText, findText.isEmpty == false else { return }
        startReplacementSession(findText: findText, beforeContext: beforeContext, afterContext: afterContext, initialText: replaceText)
    }

    @discardableResult
    func applyFinalReplacement(
        toolCallID: String,
        findText: String,
        beforeContext: String?,
        afterContext: String?,
        replaceText: String
    ) -> (success: Bool, error: String?) {
        if activeToolCallID != toolCallID {
            activeReplacementSession?.cancel()
            activeReplacementSession = nil
            activeToolCallID = toolCallID
        }

        if activeReplacementSession == nil {
            let started = startReplacementSession(
                findText: findText,
                beforeContext: beforeContext,
                afterContext: afterContext,
                initialText: replaceText
            )
            if started == false {
                let error = lastErrorDescription ?? "Replacement session failed to start."
                return (false, error)
            }
        } else {
            activeReplacementSession?.setText(replaceText)
        }

        if activeReplacementSession?.isActive == true {
            activeReplacementSession?.finish()
            lastErrorDescription = nil
        } else {
            let error = lastErrorDescription ?? "Replacement session became inactive."
            activeReplacementSession = nil
            activeToolCallID = nil
            return (false, error)
        }
        activeReplacementSession = nil
        activeToolCallID = nil
        return (true, nil)
    }

    @discardableResult
    private func startReplacementSession(
        findText: String,
        beforeContext: String?,
        afterContext: String?,
        initialText: String
    ) -> Bool {
        guard let editor else {
            lastErrorDescription = StreamingReplacementError.editorUnavailable.localizedDescription
            return false
        }

        do {
            let session = try editor.startReplacement(findText: findText, beforeContext: beforeContext, afterContext: afterContext)
            activeReplacementSession = session
            session.setText(initialText)
            return true
        } catch StreamingReplacementError.sessionAlreadyActive {
            activeReplacementSession?.cancel()
            activeReplacementSession = nil
            do {
                let session = try editor.startReplacement(findText: findText, beforeContext: beforeContext, afterContext: afterContext)
                activeReplacementSession = session
                session.setText(initialText)
                return true
            } catch {
                lastErrorDescription = error.localizedDescription
                return false
            }
        } catch {
            lastErrorDescription = error.localizedDescription
            return false
        }
    }
}

private enum JSONToolInputExtractor {
    static func extractStringValue(key: String, from input: String, allowPartial: Bool) -> String? {
        guard let valueStart = lastKeyMatchStart(for: key, in: input) else { return nil }

        var idx = valueStart
        while idx < input.endIndex, input[idx].isWhitespace {
            idx = input.index(after: idx)
        }
        guard idx < input.endIndex else { return nil }

        if input[idx...].hasPrefix("null") {
            return nil
        }

        guard input[idx] == "\"" else { return nil }
        idx = input.index(after: idx) // skip opening quote

        var out = ""
        out.reserveCapacity(256)

        while idx < input.endIndex {
            let ch = input[idx]
            if ch == "\"" {
                return out
            }
            if ch == "\\" {
                idx = input.index(after: idx)
                if idx >= input.endIndex { break }
                let esc = input[idx]
                switch esc {
                case "\"": out.append("\"")
                case "\\": out.append("\\")
                case "/": out.append("/")
                case "b": out.append("\u{0008}")
                case "f": out.append("\u{000C}")
                case "n": out.append("\n")
                case "r": out.append("\r")
                case "t": out.append("\t")
                case "u":
                    if let (ch, consumed) = decodeUnicodeScalar(from: input, startingAt: idx) {
                        out.append(ch)
                        // We consumed: "u" + 4 hex digits; move idx to last consumed char.
                        idx = input.index(idx, offsetBy: consumed - 1, limitedBy: input.endIndex) ?? input.endIndex
                    }
                default:
                    out.append(esc)
                }
            } else {
                out.append(ch)
            }
            idx = input.index(after: idx)
        }

        // Unterminated string: optionally return best-effort partial (useful for streaming `replaceText`).
        return allowPartial ? out : nil
    }

    private static func lastKeyMatchStart(for key: String, in input: String) -> String.Index? {
        // Best-effort extraction from incomplete JSON tool inputs:
        // ... "key" : "value..."
        let needle = "\"\(key)\""
        var searchRange = input.startIndex..<input.endIndex
        var lastMatch: Range<String.Index>?

        while let r = input.range(of: needle, options: [], range: searchRange) {
            lastMatch = r
            searchRange = r.upperBound..<input.endIndex
        }

        guard let match = lastMatch else { return nil }

        var idx = match.upperBound
        while idx < input.endIndex, input[idx].isWhitespace {
            idx = input.index(after: idx)
        }

        guard idx < input.endIndex, input[idx] == ":" else { return nil }
        idx = input.index(after: idx) // after colon
        return idx
    }

    private static func decodeUnicodeScalar(from input: String, startingAt uIndex: String.Index) -> (Character, Int)? {
        // Expects uIndex currently pointing at 'u' in a \uXXXX sequence.
        var idx = input.index(after: uIndex)
        var hex = ""
        hex.reserveCapacity(4)
        for _ in 0..<4 {
            guard idx < input.endIndex else { return nil }
            let ch = input[idx]
            guard ch.isHexDigit else { return nil }
            hex.append(ch)
            idx = input.index(after: idx)
        }
        guard let scalar = UInt32(hex, radix: 16).flatMap(UnicodeScalar.init) else { return nil }
        // consumed = "u" + 4 hex digits
        return (Character(scalar), 5)
    }
}
