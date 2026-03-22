import Foundation

enum MessageBlock {
    case text(AttributedString)
    case inlineCode(String)
    case codeBlock(language: String?, code: String)
    case fileReference(path: String)
    case image(url: URL)

    /// Deterministic ID using djb2 hash — stable across process launches.
    var id: String {
        switch self {
        case .text(let s): return "text-\(djb2(String(s.characters)))"
        case .inlineCode(let s): return "inline-\(djb2(s))"
        case .codeBlock(let lang, let code): return "code-\(lang ?? "")-\(djb2(code))"
        case .fileReference(let path): return "file-\(path)"
        case .image(let url): return "img-\(url.absoluteString)"
        }
    }

    private func djb2(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return hash
    }
}

struct ContentParser {
    private static let codeBlockPattern = try! NSRegularExpression(
        pattern: #"```(\w*)\n([\s\S]*?)```"#,
        options: []
    )

    private static let inlineCodePattern = try! NSRegularExpression(
        pattern: #"`([^`]+)`"#,
        options: []
    )

    private static let placeholderPrefix = "<<CODEBLOCK_"
    private static let placeholderSuffix = ">>"
    private static let codeBlockPlaceholderPattern = try! NSRegularExpression(
        pattern: #"<<CODEBLOCK_(\d+)>>"#
    )

    private static let filePathPattern = try! NSRegularExpression(
        pattern: #"(?<![`\w])(\.\./[\w./-]+\.\w+|\./[\w./-]+\.\w+|/(?:[\w.-]+/)+[\w.-]+\.\w+)(?![`\w])"#,
        options: []
    )

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "tiff"]

    static func parse(_ content: String) -> [MessageBlock] {
        guard !content.isEmpty else { return [] }

        var working = content
        var codeBlocks: [(range: Range<String.Index>, lang: String?, code: String)] = []

        let nsRange = NSRange(working.startIndex..., in: working)
        let codeMatches = codeBlockPattern.matches(in: working, options: [], range: nsRange)

        // Collect code block data in forward order first
        var codeBlockData: [(range: Range<String.Index>, lang: String?, code: String)] = []
        for match in codeMatches {
            guard let fullRange = Range(match.range, in: working),
                  let langRange = Range(match.range(at: 1), in: working),
                  let codeRange = Range(match.range(at: 2), in: working) else { continue }

            let lang = String(working[langRange])
            let code = String(working[codeRange]).trimmingCharacters(in: .newlines)
            codeBlockData.append((range: fullRange, lang: lang.isEmpty ? nil : lang, code: code))
        }

        // Replace in reverse order so indices don't shift, but use forward-order index for placeholders
        for (index, block) in codeBlockData.enumerated().reversed() {
            let placeholder = "\(Self.placeholderPrefix)\(index)\(Self.placeholderSuffix)"
            working.replaceSubrange(block.range, with: placeholder)
        }
        codeBlocks = codeBlockData

        var result: [MessageBlock] = []
        let segments = splitKeepingMatches(working, pattern: codeBlockPlaceholderPattern)

        for segment in segments {
            if let match = codeBlockPlaceholderPattern.firstMatch(in: segment, range: NSRange(segment.startIndex..., in: segment)),
               let indexRange = Range(match.range(at: 1), in: segment),
               let index = Int(segment[indexRange]) {
                result.append(.codeBlock(language: codeBlocks[index].lang, code: codeBlocks[index].code))
            } else {
                result.append(contentsOf: parseTextSegment(segment))
            }
        }

        return result
    }

    private static func parseTextSegment(_ text: String) -> [MessageBlock] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        var markers: [(range: Range<String.Index>, block: MessageBlock)] = []

        let nsRange = NSRange(text.startIndex..., in: text)
        for match in inlineCodePattern.matches(in: text, options: [], range: nsRange) {
            guard let fullRange = Range(match.range, in: text),
                  let codeRange = Range(match.range(at: 1), in: text) else { continue }
            markers.append((range: fullRange, block: .inlineCode(String(text[codeRange]))))
        }

        for match in filePathPattern.matches(in: text, options: [], range: nsRange) {
            guard let fullRange = Range(match.range, in: text) else { continue }
            let overlapsInlineCode = markers.contains { $0.range.overlaps(fullRange) }
            if overlapsInlineCode { continue }

            let path = String(text[fullRange])
            let ext = (path as NSString).pathExtension.lowercased()

            if imageExtensions.contains(ext), let url = URL(string: path) {
                markers.append((range: fullRange, block: .image(url: url)))
            } else {
                markers.append((range: fullRange, block: .fileReference(path: path)))
            }
        }

        markers.sort { $0.range.lowerBound < $1.range.lowerBound }

        var result: [MessageBlock] = []
        var cursor = text.startIndex

        for marker in markers {
            if cursor < marker.range.lowerBound {
                let textSlice = String(text[cursor..<marker.range.lowerBound])
                if !textSlice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let attr = try? AttributedString(markdown: textSlice) {
                        result.append(.text(attr))
                    } else {
                        result.append(.text(AttributedString(textSlice)))
                    }
                }
            }
            result.append(marker.block)
            cursor = marker.range.upperBound
        }

        if cursor < text.endIndex {
            let trailing = String(text[cursor...])
            if !trailing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let attr = try? AttributedString(markdown: trailing) {
                    result.append(.text(attr))
                } else {
                    result.append(.text(AttributedString(trailing)))
                }
            }
        }

        return result
    }

    private static func splitKeepingMatches(_ string: String, pattern: NSRegularExpression) -> [String] {
        var result: [String] = []
        var cursor = string.startIndex
        let nsRange = NSRange(string.startIndex..., in: string)

        for match in pattern.matches(in: string, options: [], range: nsRange) {
            guard let matchRange = Range(match.range, in: string) else { continue }
            if cursor < matchRange.lowerBound {
                result.append(String(string[cursor..<matchRange.lowerBound]))
            }
            result.append(String(string[matchRange]))
            cursor = matchRange.upperBound
        }

        if cursor < string.endIndex {
            result.append(String(string[cursor...]))
        }

        return result
    }
}
