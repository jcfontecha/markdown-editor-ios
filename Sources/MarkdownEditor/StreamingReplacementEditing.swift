import Foundation
import Lexical
import LexicalListPlugin
import LexicalMarkdown

public enum StreamingReplacementError: LocalizedError, Equatable {
    case emptyFindText
    case sessionAlreadyActive
    case matchNotFound
    case editorUnavailable

    public var errorDescription: String? {
        switch self {
        case .emptyFindText:
            return "Find text cannot be empty."
        case .sessionAlreadyActive:
            return "A streaming replacement session is already active."
        case .matchNotFound:
            return "Could not find matching text in the current document."
        case .editorUnavailable:
            return "Editor is unavailable."
        }
    }
}

@MainActor
public protocol MarkdownStreamingEditing: AnyObject {
    func startReplacement(
        findText: String,
        beforeContext: String?,
        afterContext: String?
    ) throws -> ReplacementSession
}

@MainActor
public final class ReplacementSession {
    private weak var owner: MarkdownStreamingEditingInternal?
    private let token: UUID

    internal init(owner: MarkdownStreamingEditingInternal, token: UUID) {
        self.owner = owner
        self.token = token
    }

    public var isActive: Bool {
        owner?.isReplacementSessionActive(token: token) ?? false
    }

    public func append(_ delta: String) {
        owner?.appendReplacementDelta(token: token, delta: delta)
    }

    public func setText(_ fullText: String) {
        owner?.setReplacementText(token: token, fullText: fullText)
    }

    public func finish() {
        owner?.finishReplacement(token: token)
    }

    public func cancel() {
        owner?.cancelReplacement(token: token)
    }
}

@MainActor
internal protocol MarkdownStreamingEditingInternal: AnyObject {
    func isReplacementSessionActive(token: UUID) -> Bool
    func appendReplacementDelta(token: UUID, delta: String)
    func setReplacementText(token: UUID, fullText: String)
    func finishReplacement(token: UUID)
    func cancelReplacement(token: UUID)
}

internal struct StreamingReplacementMatchCandidate {
    let nodeKey: NodeKey
    let rawText: String
    let normalizedText: String
    let ordinal: Int
}

internal struct StreamingReplacementMatchResult {
    let nodeKey: NodeKey
    let rawText: String
}

internal enum StreamingReplacementMatching {
    private static let zeroWidthScalars = Set<Unicode.Scalar>([
        "\u{200B}", // zero width space
        "\u{200C}", // zero width non-joiner
        "\u{200D}", // zero width joiner
        "\u{FEFF}", // byte order mark
    ])

    private static let nbspScalars = Set<Unicode.Scalar>([
        "\u{00A0}", // nbsp
        "\u{202F}", // narrow no-break space
        "\u{2007}", // figure space
        "\u{2009}", // thin space
    ])

    private static let punctuationMap: [Unicode.Scalar: String] = [
        "\u{2018}": "'", // ‘
        "\u{2019}": "'", // ’
        "\u{201C}": "\"", // “
        "\u{201D}": "\"", // ”
        "\u{2013}": "-", // –
        "\u{2014}": "-", // —
        "\u{2212}": "-", // −
        "\u{2026}": "...", // …
    ]

    static func normalizeForMatching(_ input: String) -> String {
        if input.isEmpty { return "" }

        var output = ""
        output.reserveCapacity(input.count)

        var lastWasSpace = false

        var iterator = input.unicodeScalars.makeIterator()
        while let scalar = iterator.next() {
            if zeroWidthScalars.contains(scalar) { continue }

            if scalar == "\r" {
                if let next = iterator.next(), next == "\n" {
                    output.append("\n")
                } else {
                    output.append("\n")
                }
                lastWasSpace = false
                continue
            }

            if scalar == "\n" {
                output.append("\n")
                lastWasSpace = false
                continue
            }

            if nbspScalars.contains(scalar) || scalar == "\t" || scalar == "\u{000B}" || scalar == "\u{000C}" {
                if !lastWasSpace {
                    output.append(" ")
                    lastWasSpace = true
                }
                continue
            }

            if let mapped = punctuationMap[scalar] {
                output.append(mapped)
                lastWasSpace = false
                continue
            }

            if CharacterSet.whitespaces.contains(scalar) {
                if !lastWasSpace {
                    output.append(" ")
                    lastWasSpace = true
                }
                continue
            }

            output.unicodeScalars.append(scalar)
            lastWasSpace = false
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func bestMatch(
        candidates: [StreamingReplacementMatchCandidate],
        findText: String,
        beforeContext: String?,
        afterContext: String?
    ) -> StreamingReplacementMatchResult? {
        let needle = normalizeForMatching(findText)
        guard !needle.isEmpty else { return nil }

        let before = normalizeForMatching(beforeContext ?? "")
        let after = normalizeForMatching(afterContext ?? "")

        var best: (score: Int, matchIndex: Int, ordinal: Int, result: StreamingReplacementMatchResult)? = nil

        for candidate in candidates {
            guard let range = candidate.normalizedText.range(of: needle) else { continue }
            let matchIndex = candidate.normalizedText.distance(from: candidate.normalizedText.startIndex, to: range.lowerBound)

            var score = 1_000

            if !before.isEmpty {
                let beforeText = String(candidate.normalizedText.prefix(matchIndex))
                let overlap = commonSuffixLength(beforeText, before)
                score += Int((Double(overlap) / Double(max(1, before.count))) * 500.0)
            }

            if !after.isEmpty {
                let start = candidate.normalizedText.index(range.upperBound, offsetBy: 0)
                let afterText = String(candidate.normalizedText[start...])
                let overlap = commonPrefixLength(afterText, after)
                score += Int((Double(overlap) / Double(max(1, after.count))) * 500.0)
            }

            let result = StreamingReplacementMatchResult(nodeKey: candidate.nodeKey, rawText: candidate.rawText)

            if let currentBest = best {
                if score > currentBest.score ||
                    (score == currentBest.score && matchIndex < currentBest.matchIndex) ||
                    (score == currentBest.score && matchIndex == currentBest.matchIndex && candidate.ordinal < currentBest.ordinal) {
                    best = (score, matchIndex, candidate.ordinal, result)
                }
            } else {
                best = (score, matchIndex, candidate.ordinal, result)
            }
        }

        return best?.result
    }

    private static func commonPrefixLength(_ a: String, _ b: String) -> Int {
        let maxLen = min(a.count, b.count)
        if maxLen == 0 { return 0 }

        var length = 0
        let aChars = Array(a)
        let bChars = Array(b)
        for i in 0..<maxLen {
            if aChars[i] != bChars[i] { break }
            length += 1
        }
        return length
    }

    private static func commonSuffixLength(_ a: String, _ b: String) -> Int {
        let maxLen = min(a.count, b.count)
        if maxLen == 0 { return 0 }

        var length = 0
        let aChars = Array(a)
        let bChars = Array(b)
        for i in 1...maxLen {
            if aChars[aChars.count - i] != bChars[bChars.count - i] { break }
            length += 1
        }
        return length
    }
}

