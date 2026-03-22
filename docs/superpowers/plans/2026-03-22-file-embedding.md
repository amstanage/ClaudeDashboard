# File Embedding & Rich Content Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add rich content rendering (markdown, syntax-highlighted code blocks, file previews, drag-and-drop attachments) to the Claude Dashboard chat window.

**Architecture:** Hybrid native SwiftUI with targeted NSViewRepresentable wrappers. A ContentParser breaks message strings into typed MessageBlock arrays. Each block type gets its own focused view. File attachments are a separate data path on ChatMessage, not parsed from text.

**Tech Stack:** Swift 6.0, SwiftUI, AppKit (NSTextView for code blocks, PDFKit for PDF preview), XCTest

**Spec:** `docs/superpowers/specs/2026-03-22-file-embedding-design.md`

**Project root:** `/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard/`
**Source root:** `ClaudeDashboard/` (relative to project root)
**Test root:** `ClaudeDashboardTests/` (relative to project root)
**Test import:** `@testable import Claude_Dashboard` (note: underscored because product name is "Claude Dashboard")

**XcodeGen:** This project uses XcodeGen. After creating or deleting any `.swift` file, you **must** regenerate the Xcode project before building:
```bash
cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodegen generate
```

**Build command:** `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodegen generate && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' build 2>&1 | tail -5`
**Test command:** `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodegen generate && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' test 2>&1 | tail -20`

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `ClaudeDashboard/Models/FileAttachment.swift` | FileAttachment struct with FileType enum, thumbnail as Data |
| `ClaudeDashboard/Services/ContentParser.swift` | MessageBlock enum + parse(content:) function |
| `ClaudeDashboard/Services/SyntaxHighlighter.swift` | Token-based syntax colorizer producing NSAttributedString |
| `ClaudeDashboard/Views/Chat/MessageContentView.swift` | Renders [MessageBlock] as vertical stack of typed views |
| `ClaudeDashboard/Views/Chat/CodeBlockView.swift` | NSViewRepresentable wrapping NSTextView for highlighted code |
| `ClaudeDashboard/Views/Chat/FileReferenceView.swift` | Tappable file chip with expand/collapse inline preview |
| `ClaudeDashboard/Views/Chat/AttachmentChipView.swift` | Reusable attachment chip (used in input area + message bubbles) |
| `ClaudeDashboardTests/ContentParserTests.swift` | Unit tests for content parsing |
| `ClaudeDashboardTests/SyntaxHighlighterTests.swift` | Unit tests for syntax highlighting |
| `ClaudeDashboardTests/FileAttachmentTests.swift` | Unit tests for FileAttachment model |

### Modified Files

| File | What Changes |
|------|-------------|
| `ClaudeDashboard/Models/ChatMessage.swift` | Add `attachments: [FileAttachment]` field with default `[]` |
| `ClaudeDashboard/Views/Chat/MessageBubbleView.swift` | Replace `Text()` body with `MessageContentView` + attachment chips |
| `ClaudeDashboard/Views/Chat/MessageInputView.swift` | Add paperclip button, drop zone, attachment chip row |
| `ClaudeDashboard/ViewModels/ChatViewModel.swift` | Add `pendingAttachments`, async file reading, compose message |

---

## Task 1: FileAttachment Model

**Files:**
- Create: `ClaudeDashboard/Models/FileAttachment.swift`
- Create: `ClaudeDashboardTests/FileAttachmentTests.swift`

- [ ] **Step 1: Write the test file**

```swift
import XCTest
@testable import Claude_Dashboard

final class FileAttachmentTests: XCTestCase {
    func testFileTypeFromExtension() {
        XCTAssertEqual(FileAttachment.fileType(for: "photo.png"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "photo.jpg"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "photo.jpeg"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "photo.gif"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "photo.svg"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "photo.webp"), .image)
        XCTAssertEqual(FileAttachment.fileType(for: "doc.pdf"), .pdf)
        XCTAssertEqual(FileAttachment.fileType(for: "main.swift"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "app.py"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "index.js"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "index.ts"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "main.go"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "main.rs"), .code)
        XCTAssertEqual(FileAttachment.fileType(for: "readme.md"), .text)
        XCTAssertEqual(FileAttachment.fileType(for: "notes.txt"), .text)
        XCTAssertEqual(FileAttachment.fileType(for: "data.bin"), .other)
        XCTAssertEqual(FileAttachment.fileType(for: "noextension"), .other)
    }

    func testEquatableByID() {
        let id = UUID()
        let a = FileAttachment(id: id, url: URL(fileURLWithPath: "/a.txt"), fileName: "a.txt", fileType: .text, fileSize: 100, thumbnailData: nil)
        let b = FileAttachment(id: id, url: URL(fileURLWithPath: "/b.txt"), fileName: "b.txt", fileType: .code, fileSize: 200, thumbnailData: nil)
        XCTAssertEqual(a, b, "Equality is by ID only")
    }

    func testHashableByID() {
        let id = UUID()
        let a = FileAttachment(id: id, url: URL(fileURLWithPath: "/a.txt"), fileName: "a.txt", fileType: .text, fileSize: 100, thumbnailData: nil)
        let b = FileAttachment(id: id, url: URL(fileURLWithPath: "/b.txt"), fileName: "b.txt", fileType: .code, fileSize: 200, thumbnailData: nil)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testFileSizeLimits() {
        // 1MB limit per file
        XCTAssertTrue(FileAttachment.isWithinSizeLimit(bytes: 1_000_000))
        XCTAssertFalse(FileAttachment.isWithinSizeLimit(bytes: 1_000_001))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' test 2>&1 | grep -E "(FileAttachment|Build FAILED|error:)" | head -10`
Expected: Build failure — `FileAttachment` not defined

- [ ] **Step 3: Write FileAttachment model**

Create `ClaudeDashboard/Models/FileAttachment.swift`:

```swift
import AppKit

struct FileAttachment: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let fileName: String
    let fileType: FileType
    let fileSize: Int64
    let thumbnailData: Data?

    enum FileType: Equatable, Hashable, Sendable {
        case image, pdf, code, text, other
    }

    var thumbnail: NSImage? {
        thumbnailData.flatMap { NSImage(data: $0) }
    }

    static func == (lhs: FileAttachment, rhs: FileAttachment) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let maxFileSize: Int64 = 1_000_000 // 1MB
    static let maxTotalSize: Int64 = 5_000_000 // 5MB
    static let maxFileCount = 10

    static func isWithinSizeLimit(bytes: Int64) -> Bool {
        bytes <= maxFileSize
    }

    static func fileType(for fileName: String) -> FileType {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "tiff": return .image
        case "pdf": return .pdf
        case "swift", "py", "js", "ts", "tsx", "jsx", "go", "rs", "rb",
             "java", "kt", "c", "cpp", "h", "hpp", "m", "cs", "sh",
             "bash", "zsh", "json", "yaml", "yml", "toml", "xml",
             "html", "css", "scss", "sql", "r", "lua", "zig",
             "dockerfile", "makefile": return .code
        case "txt", "md", "markdown", "rst", "csv", "log": return .text
        default: return .other
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' test 2>&1 | grep -E "(Test Suite|Test Case|passed|failed)" | head -10`
Expected: All FileAttachmentTests pass

- [ ] **Step 5: Add attachments field to ChatMessage**

Modify `ClaudeDashboard/Models/ChatMessage.swift`:
- Add `var attachments: [FileAttachment]` field
- Add `attachments: [FileAttachment] = []` parameter to `init`

```swift
struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    let model: String?
    var tokensIn: Int?
    var tokensOut: Int?
    var isComplete: Bool
    var attachments: [FileAttachment]

    // ... MessageRole enum unchanged ...

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        model: String? = nil,
        tokensIn: Int? = nil,
        tokensOut: Int? = nil,
        isComplete: Bool = true,
        attachments: [FileAttachment] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.model = model
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.isComplete = isComplete
        self.attachments = attachments
    }
}
```

- [ ] **Step 6: Build to verify existing tests still pass**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' test 2>&1 | grep -E "(Test Suite|passed|failed)" | head -10`
Expected: All existing tests pass (default `[]` is backward compatible)

- [ ] **Step 7: Commit**

```bash
cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard"
git add ClaudeDashboard/Models/FileAttachment.swift ClaudeDashboard/Models/ChatMessage.swift ClaudeDashboardTests/FileAttachmentTests.swift
git commit -m "feat: add FileAttachment model and attachments field to ChatMessage"
```

---

## Task 2: Content Parser

**Files:**
- Create: `ClaudeDashboard/Services/ContentParser.swift`
- Create: `ClaudeDashboardTests/ContentParserTests.swift`

- [ ] **Step 1: Write the test file**

```swift
import XCTest
@testable import Claude_Dashboard

final class ContentParserTests: XCTestCase {

    // MARK: - Plain text

    func testPlainTextReturnsOneTextBlock() {
        let blocks = ContentParser.parse("Hello world")
        XCTAssertEqual(blocks.count, 1)
        guard case .text = blocks[0] else { return XCTFail("Expected .text") }
    }

    func testEmptyStringReturnsEmpty() {
        let blocks = ContentParser.parse("")
        XCTAssertTrue(blocks.isEmpty)
    }

    // MARK: - Code blocks

    func testFencedCodeBlockWithLanguage() {
        let input = "Before\n```swift\nlet x = 1\n```\nAfter"
        let blocks = ContentParser.parse(input)
        XCTAssertEqual(blocks.count, 3)
        guard case .text = blocks[0] else { return XCTFail("Expected .text") }
        guard case .codeBlock(let lang, let code) = blocks[1] else { return XCTFail("Expected .codeBlock") }
        XCTAssertEqual(lang, "swift")
        XCTAssertEqual(code, "let x = 1")
        guard case .text = blocks[2] else { return XCTFail("Expected .text") }
    }

    func testFencedCodeBlockWithoutLanguage() {
        let input = "```\nsome code\n```"
        let blocks = ContentParser.parse(input)
        XCTAssertEqual(blocks.count, 1)
        guard case .codeBlock(let lang, let code) = blocks[0] else { return XCTFail("Expected .codeBlock") }
        XCTAssertNil(lang)
        XCTAssertEqual(code, "some code")
    }

    func testMultipleCodeBlocks() {
        let input = "```python\nprint('a')\n```\ntext\n```js\nconsole.log('b')\n```"
        let blocks = ContentParser.parse(input)
        XCTAssertEqual(blocks.count, 3)
        guard case .codeBlock(let lang1, _) = blocks[0] else { return XCTFail("Expected .codeBlock") }
        XCTAssertEqual(lang1, "python")
        guard case .text = blocks[1] else { return XCTFail("Expected .text") }
        guard case .codeBlock(let lang2, _) = blocks[2] else { return XCTFail("Expected .codeBlock") }
        XCTAssertEqual(lang2, "js")
    }

    func testCodeBlockPreservesInternalNewlines() {
        let input = "```\nline1\nline2\nline3\n```"
        let blocks = ContentParser.parse(input)
        guard case .codeBlock(_, let code) = blocks[0] else { return XCTFail("Expected .codeBlock") }
        XCTAssertEqual(code, "line1\nline2\nline3")
    }

    // MARK: - Inline code

    func testInlineCode() {
        let input = "Use `let x = 1` here"
        let blocks = ContentParser.parse(input)
        XCTAssertEqual(blocks.count, 3)
        guard case .text = blocks[0] else { return XCTFail("Expected .text") }
        guard case .inlineCode(let code) = blocks[1] else { return XCTFail("Expected .inlineCode") }
        XCTAssertEqual(code, "let x = 1")
        guard case .text = blocks[2] else { return XCTFail("Expected .text") }
    }

    func testInlineCodeInsideCodeBlockNotParsed() {
        let input = "```\n`not inline` just code\n```"
        let blocks = ContentParser.parse(input)
        XCTAssertEqual(blocks.count, 1)
        guard case .codeBlock(_, let code) = blocks[0] else { return XCTFail("Expected .codeBlock") }
        XCTAssertTrue(code.contains("`not inline`"))
    }

    // MARK: - File references

    func testAbsoluteFilePath() {
        let input = "Check /Users/alex/project/main.swift for details"
        let blocks = ContentParser.parse(input)
        let fileRefs = blocks.compactMap { block -> String? in
            guard case .fileReference(let path) = block else { return nil }
            return path
        }
        XCTAssertEqual(fileRefs, ["/Users/alex/project/main.swift"])
    }

    func testRelativeFilePath() {
        let input = "See ./src/app.ts for the code"
        let blocks = ContentParser.parse(input)
        let fileRefs = blocks.compactMap { block -> String? in
            guard case .fileReference(let path) = block else { return nil }
            return path
        }
        XCTAssertEqual(fileRefs, ["./src/app.ts"])
    }

    func testRelativePathWithoutExtensionNotDetected() {
        let input = "Go to ../config for settings"
        let blocks = ContentParser.parse(input)
        let fileRefs = blocks.compactMap { block -> String? in
            guard case .fileReference(let path) = block else { return nil }
            return path
        }
        XCTAssertTrue(fileRefs.isEmpty, "Bare ../config should not match — no extension")
    }

    func testPathInsideCodeBlockNotDetected() {
        let input = "```\n/usr/bin/swift\n```"
        let blocks = ContentParser.parse(input)
        XCTAssertEqual(blocks.count, 1)
        guard case .codeBlock = blocks[0] else { return XCTFail("Expected .codeBlock, not file ref") }
    }

    // MARK: - Stable IDs

    func testStableBlockIDs() {
        let blocks1 = ContentParser.parse("Hello\n```swift\ncode\n```")
        let blocks2 = ContentParser.parse("Hello\n```swift\ncode\n```")
        XCTAssertEqual(blocks1.map(\.id), blocks2.map(\.id), "Same content should produce same IDs")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' test 2>&1 | grep -E "(ContentParser|Build FAILED|error:)" | head -10`
Expected: Build failure — `ContentParser` not defined

- [ ] **Step 3: Write ContentParser**

Create `ClaudeDashboard/Services/ContentParser.swift`:

```swift
import Foundation

enum MessageBlock {
    case text(AttributedString)
    case inlineCode(String)
    case codeBlock(language: String?, code: String)
    case fileReference(path: String)
    case image(url: URL)

    /// Deterministic ID using djb2 hash — stable across process launches.
    /// Swift's built-in hashValue uses randomized seeding, so we can't rely on it.
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
    /// Regex for fenced code blocks: ```optional-lang\n...code...\n```
    private static let codeBlockPattern = try! NSRegularExpression(
        pattern: #"```(\w*)\n([\s\S]*?)```"#,
        options: []
    )

    /// Regex for inline code: `...`
    private static let inlineCodePattern = try! NSRegularExpression(
        pattern: #"`([^`]+)`"#,
        options: []
    )

    /// Placeholder pattern for code blocks during parsing
    private static let codeBlockPlaceholderPattern = try! NSRegularExpression(
        pattern: #"\u{FFFC}CODE_(\d+)\u{FFFC}"#
    )

    /// Regex for file paths:
    /// - Absolute: /path/to/file.ext (at least one / separator and a dot extension)
    /// - Relative: ./path/to/file.ext or ../path/to/file.ext (must have extension)
    private static let filePathPattern = try! NSRegularExpression(
        pattern: #"(?<![`\w])(\.\./[\w./-]+\.\w+|\./[\w./-]+\.\w+|/(?:[\w.-]+/)+[\w.-]+\.\w+)(?![`\w])"#,
        options: []
    )

    /// Image file extensions
    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "svg", "webp", "bmp", "tiff"]

    static func parse(_ content: String) -> [MessageBlock] {
        guard !content.isEmpty else { return [] }

        // Phase 1: Extract fenced code blocks, replacing them with placeholders
        var working = content
        var codeBlocks: [(range: Range<String.Index>, lang: String?, code: String)] = []

        let nsRange = NSRange(working.startIndex..., in: working)
        let codeMatches = codeBlockPattern.matches(in: working, options: [], range: nsRange)

        // Collect code blocks (in reverse so replacements don't shift indices)
        for match in codeMatches.reversed() {
            guard let fullRange = Range(match.range, in: working),
                  let langRange = Range(match.range(at: 1), in: working),
                  let codeRange = Range(match.range(at: 2), in: working) else { continue }

            let lang = String(working[langRange])
            let code = String(working[codeRange]).trimmingCharacters(in: .newlines)
            let placeholder = "\u{FFFC}CODE_\(codeBlocks.count)\u{FFFC}"

            codeBlocks.insert((range: fullRange, lang: lang.isEmpty ? nil : lang, code: code), at: 0)
            working.replaceSubrange(fullRange, with: placeholder)
        }

        // Phase 2: Split on code block placeholders and process each text segment
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

    /// Parse a text segment (no fenced code blocks) into text, inline code, and file references
    private static func parseTextSegment(_ text: String) -> [MessageBlock] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        // Find all inline code and file path matches
        var markers: [(range: Range<String.Index>, block: MessageBlock)] = []

        // Inline code
        let nsRange = NSRange(text.startIndex..., in: text)
        for match in inlineCodePattern.matches(in: text, options: [], range: nsRange) {
            guard let fullRange = Range(match.range, in: text),
                  let codeRange = Range(match.range(at: 1), in: text) else { continue }
            markers.append((range: fullRange, block: .inlineCode(String(text[codeRange]))))
        }

        // File paths (skip those inside inline code ranges)
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

        // Sort markers by position
        markers.sort { $0.range.lowerBound < $1.range.lowerBound }

        // Build result: interleave text blocks with markers
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

        // Trailing text
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

    /// Split a string by a regex pattern, keeping both the non-matching and matching segments in order
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' test 2>&1 | grep -E "(ContentParser|passed|failed)" | head -10`
Expected: All ContentParserTests pass

- [ ] **Step 5: Commit**

```bash
cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard"
git add ClaudeDashboard/Services/ContentParser.swift ClaudeDashboardTests/ContentParserTests.swift
git commit -m "feat: add ContentParser with MessageBlock types for rich content parsing"
```

---

## Task 3: Syntax Highlighter

**Files:**
- Create: `ClaudeDashboard/Services/SyntaxHighlighter.swift`
- Create: `ClaudeDashboardTests/SyntaxHighlighterTests.swift`

- [ ] **Step 1: Write the test file**

```swift
import XCTest
import AppKit
@testable import Claude_Dashboard

final class SyntaxHighlighterTests: XCTestCase {
    func testSwiftKeywordsHighlighted() {
        let code = "let x = 1"
        let result = SyntaxHighlighter.highlight(code, language: "swift")
        // "let" should have keyword color, not the default color
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertNotNil(color, "Keywords should have a foreground color")
    }

    func testStringLiteralsHighlighted() {
        let code = #"let name = "hello""#
        let result = SyntaxHighlighter.highlight(code, language: "swift")
        // Find the range of "hello" and check it has string color
        let helloRange = (code as NSString).range(of: #""hello""#)
        let attrs = result.attributes(at: helloRange.location, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertNotNil(color)
    }

    func testCommentsHighlighted() {
        let code = "// this is a comment\nlet x = 1"
        let result = SyntaxHighlighter.highlight(code, language: "swift")
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertNotNil(color)
    }

    func testUnknownLanguageFallsBackToPlain() {
        let code = "some random code"
        let result = SyntaxHighlighter.highlight(code, language: "brainfuck")
        XCTAssertEqual(result.string, code)
        // Should still have the base monospaced font applied
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let font = attrs[.font] as? NSFont
        XCTAssertNotNil(font)
    }

    func testNilLanguageFallsBackToPlain() {
        let code = "just text"
        let result = SyntaxHighlighter.highlight(code, language: nil)
        XCTAssertEqual(result.string, code)
    }

    func testNumbersHighlighted() {
        let code = "let x = 42"
        let result = SyntaxHighlighter.highlight(code, language: "swift")
        let numRange = (code as NSString).range(of: "42")
        let attrs = result.attributes(at: numRange.location, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertNotNil(color)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: build and test, expect failure because `SyntaxHighlighter` doesn't exist

- [ ] **Step 3: Write SyntaxHighlighter**

Create `ClaudeDashboard/Services/SyntaxHighlighter.swift`:

```swift
import AppKit

struct SyntaxHighlighter {
    // MARK: - Theme Colors (dark background)

    private static let keywordColor = NSColor(red: 0.78, green: 0.47, blue: 0.86, alpha: 1.0)   // purple
    private static let stringColor = NSColor(red: 0.90, green: 0.44, blue: 0.40, alpha: 1.0)     // red
    private static let commentColor = NSColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1.0)    // gray
    private static let numberColor = NSColor(red: 0.82, green: 0.68, blue: 0.33, alpha: 1.0)     // yellow
    private static let typeColor = NSColor(red: 0.35, green: 0.76, blue: 0.83, alpha: 1.0)       // cyan
    private static let defaultColor = NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)    // light gray
    private static let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    // MARK: - Language Keywords

    private static let keywords: [String: Set<String>] = [
        "swift": ["let", "var", "func", "class", "struct", "enum", "protocol", "import", "return",
                  "if", "else", "guard", "switch", "case", "default", "for", "while", "repeat",
                  "break", "continue", "in", "where", "throws", "throw", "try", "catch", "async",
                  "await", "self", "Self", "true", "false", "nil", "init", "deinit", "private",
                  "public", "internal", "fileprivate", "open", "static", "override", "final",
                  "mutating", "typealias", "extension", "some", "any", "weak", "unowned"],
        "python": ["def", "class", "import", "from", "return", "if", "elif", "else", "for", "while",
                   "break", "continue", "pass", "try", "except", "finally", "raise", "with", "as",
                   "yield", "lambda", "and", "or", "not", "in", "is", "True", "False", "None",
                   "async", "await", "self", "print"],
        "javascript": ["const", "let", "var", "function", "return", "if", "else", "for", "while",
                       "break", "continue", "switch", "case", "default", "try", "catch", "finally",
                       "throw", "new", "this", "class", "extends", "import", "export", "from",
                       "async", "await", "yield", "true", "false", "null", "undefined", "typeof",
                       "instanceof", "of", "in", "delete", "void"],
        "typescript": ["const", "let", "var", "function", "return", "if", "else", "for", "while",
                       "break", "continue", "switch", "case", "default", "try", "catch", "finally",
                       "throw", "new", "this", "class", "extends", "implements", "import", "export",
                       "from", "async", "await", "yield", "true", "false", "null", "undefined",
                       "typeof", "instanceof", "interface", "type", "enum", "as", "is", "keyof",
                       "readonly", "public", "private", "protected", "static", "abstract"],
        "go": ["func", "return", "if", "else", "for", "range", "switch", "case", "default", "break",
               "continue", "go", "defer", "select", "chan", "map", "struct", "interface", "type",
               "package", "import", "var", "const", "true", "false", "nil", "error"],
        "rust": ["fn", "let", "mut", "const", "if", "else", "match", "for", "while", "loop", "break",
                 "continue", "return", "struct", "enum", "impl", "trait", "use", "mod", "pub", "crate",
                 "self", "Self", "true", "false", "as", "in", "ref", "async", "await", "move", "where",
                 "type", "unsafe", "extern", "dyn", "static"],
        "shell": ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac",
                  "in", "function", "return", "exit", "echo", "export", "source", "local", "readonly",
                  "cd", "ls", "grep", "sed", "awk", "cat", "mkdir", "rm", "cp", "mv"],
        "json": [],
        "yaml": [],
        "html": [],
        "css": [],
        "sql": ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
                "CREATE", "TABLE", "ALTER", "DROP", "INDEX", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER",
                "ON", "AND", "OR", "NOT", "NULL", "TRUE", "FALSE", "AS", "ORDER", "BY", "GROUP",
                "HAVING", "LIMIT", "OFFSET", "DISTINCT", "UNION", "ALL", "EXISTS", "IN", "LIKE",
                "BETWEEN", "IS", "CASE", "WHEN", "THEN", "ELSE", "END", "COUNT", "SUM", "AVG",
                "MAX", "MIN", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "CONSTRAINT", "DEFAULT"],
        "c": ["if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
              "return", "struct", "enum", "typedef", "union", "void", "int", "char", "float", "double",
              "long", "short", "unsigned", "signed", "const", "static", "extern", "sizeof", "NULL",
              "include", "define", "ifdef", "ifndef", "endif", "pragma"],
        "java": ["class", "interface", "extends", "implements", "import", "package", "return", "if",
                 "else", "for", "while", "do", "switch", "case", "default", "break", "continue",
                 "try", "catch", "finally", "throw", "throws", "new", "this", "super", "void",
                 "int", "long", "float", "double", "boolean", "char", "byte", "short", "null",
                 "true", "false", "public", "private", "protected", "static", "final", "abstract",
                 "synchronized", "volatile", "transient", "instanceof", "enum", "assert"],
        "kotlin": ["fun", "val", "var", "class", "object", "interface", "return", "if", "else",
                   "when", "for", "while", "do", "break", "continue", "try", "catch", "finally",
                   "throw", "import", "package", "is", "as", "in", "out", "true", "false", "null",
                   "this", "super", "companion", "data", "sealed", "abstract", "open", "override",
                   "private", "public", "protected", "internal", "suspend", "inline", "typealias"],
        "ruby": ["def", "end", "class", "module", "if", "elsif", "else", "unless", "case", "when",
                 "while", "until", "for", "do", "begin", "rescue", "ensure", "raise", "return",
                 "yield", "block_given?", "require", "include", "extend", "attr_accessor",
                 "attr_reader", "attr_writer", "self", "true", "false", "nil", "and", "or", "not",
                 "puts", "print", "lambda", "proc"],
    ]

    // Aliases: map common language names to canonical ones
    private static let languageAliases: [String: String] = [
        "js": "javascript", "ts": "typescript", "tsx": "typescript", "jsx": "javascript",
        "sh": "shell", "bash": "shell", "zsh": "shell",
        "cpp": "c", "h": "c", "hpp": "c",
        "kt": "kotlin", "rb": "ruby",
        "yml": "yaml",
        "py": "python", "rs": "rust",
    ]

    // MARK: - Patterns

    /// Languages that use // for single-line comments
    private static let slashCommentLangs: Set<String> = [
        "swift", "javascript", "typescript", "go", "rust", "c", "java", "kotlin"
    ]
    /// Languages that use # for single-line comments
    private static let hashCommentLangs: Set<String> = [
        "python", "shell", "ruby", "yaml"
    ]

    private static let slashCommentPattern = try! NSRegularExpression(pattern: #"//.*$"#, options: .anchorsMatchLines)
    private static let hashCommentPattern = try! NSRegularExpression(pattern: #"#.*$"#, options: .anchorsMatchLines)
    private static let multiLineCommentPattern = try! NSRegularExpression(pattern: #"/\*[\s\S]*?\*/"#, options: [])
    private static let doubleQuoteStringPattern = try! NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*""#, options: [])
    private static let singleQuoteStringPattern = try! NSRegularExpression(pattern: #"'(?:[^'\\]|\\.)*'"#, options: [])
    private static let numberPattern = try! NSRegularExpression(pattern: #"\b\d+\.?\d*\b"#, options: [])
    private static let wordPattern = try! NSRegularExpression(pattern: #"\b[A-Za-z_]\w*\b"#, options: [])

    // MARK: - Public API

    static func highlight(_ code: String, language: String?) -> NSAttributedString {
        let result = NSMutableAttributedString(string: code, attributes: [
            .font: monoFont,
            .foregroundColor: defaultColor,
        ])

        guard let lang = language else { return result }
        let canonical = languageAliases[lang.lowercased()] ?? lang.lowercased()
        guard let langKeywords = keywords[canonical] else { return result }

        let fullRange = NSRange(location: 0, length: result.length)

        // Track ranges that are already colored (comments, strings) so we don't re-color them
        var coloredRanges: [NSRange] = []

        // Comments — apply only the pattern appropriate for this language
        if slashCommentLangs.contains(canonical) {
            for match in slashCommentPattern.matches(in: code, range: fullRange) {
                result.addAttribute(.foregroundColor, value: commentColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }
        if hashCommentLangs.contains(canonical) {
            for match in hashCommentPattern.matches(in: code, range: fullRange) {
                result.addAttribute(.foregroundColor, value: commentColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        // Multi-line comments (/* ... */ — C-family languages)
        if slashCommentLangs.contains(canonical) {
            for match in multiLineCommentPattern.matches(in: code, range: fullRange) {
                result.addAttribute(.foregroundColor, value: commentColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        // Strings (double-quoted)
        for match in doubleQuoteStringPattern.matches(in: code, range: fullRange) {
            if !overlaps(match.range, with: coloredRanges) {
                result.addAttribute(.foregroundColor, value: stringColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        // Strings (single-quoted)
        for match in singleQuoteStringPattern.matches(in: code, range: fullRange) {
            if !overlaps(match.range, with: coloredRanges) {
                result.addAttribute(.foregroundColor, value: stringColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        // Numbers
        for match in numberPattern.matches(in: code, range: fullRange) {
            if !overlaps(match.range, with: coloredRanges) {
                result.addAttribute(.foregroundColor, value: numberColor, range: match.range)
                coloredRanges.append(match.range)
            }
        }

        // Keywords and type names
        for match in wordPattern.matches(in: code, range: fullRange) {
            if overlaps(match.range, with: coloredRanges) { continue }
            guard let wordRange = Range(match.range, in: code) else { continue }
            let word = String(code[wordRange])

            if langKeywords.contains(word) {
                result.addAttribute(.foregroundColor, value: keywordColor, range: match.range)
            } else if word.first?.isUppercase == true {
                result.addAttribute(.foregroundColor, value: typeColor, range: match.range)
            }
        }

        return result
    }

    private static func overlaps(_ range: NSRange, with ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange($0, range).length > 0 }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' test 2>&1 | grep -E "(SyntaxHighlighter|passed|failed)" | head -10`
Expected: All SyntaxHighlighterTests pass

- [ ] **Step 5: Commit**

```bash
cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard"
git add ClaudeDashboard/Services/SyntaxHighlighter.swift ClaudeDashboardTests/SyntaxHighlighterTests.swift
git commit -m "feat: add token-based SyntaxHighlighter for code block rendering"
```

---

## Task 4: CodeBlockView

**Files:**
- Create: `ClaudeDashboard/Views/Chat/CodeBlockView.swift`

- [ ] **Step 1: Write CodeBlockView**

Create `ClaudeDashboard/Views/Chat/CodeBlockView.swift`:

```swift
import SwiftUI
import AppKit

struct CodeBlockView: View {
    let code: String
    let language: String?

    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: language label + copy button
            HStack {
                if let language {
                    Text(language)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            // Code content
            HighlightedTextView(code: code, language: language)
                .frame(minHeight: 20)
        }
        .background(Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// NSViewRepresentable that wraps NSTextView for syntax-highlighted code
struct HighlightedTextView: NSViewRepresentable {
    let code: String
    let language: String?

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        scrollView.autohidesScrollers = true

        applyHighlighting(to: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        applyHighlighting(to: textView)
    }

    private func applyHighlighting(to textView: NSTextView) {
        let highlighted = SyntaxHighlighter.highlight(code, language: language)
        textView.textStorage?.setAttributedString(highlighted)
        // Do NOT manually set frame sizes here — sizeThatFits handles layout.
    }

    /// Let SwiftUI drive the sizing. This avoids conflicts with manual frame manipulation.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let textView = nsView.documentView as? NSTextView else { return nil }
        let width = proposal.width ?? 400
        textView.textContainer?.containerSize = NSSize(width: width - 16, height: .greatestFiniteMagnitude)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        if let layoutManager = textView.layoutManager, let textContainer = textView.textContainer {
            let usedRect = layoutManager.usedRect(for: textContainer)
            return CGSize(width: width, height: usedRect.height + 16)
        }
        return nil
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard"
git add ClaudeDashboard/Views/Chat/CodeBlockView.swift
git commit -m "feat: add CodeBlockView with syntax highlighting via NSViewRepresentable"
```

---

## Task 5: MessageContentView

**Files:**
- Create: `ClaudeDashboard/Views/Chat/MessageContentView.swift`

- [ ] **Step 1: Write MessageContentView**

Create `ClaudeDashboard/Views/Chat/MessageContentView.swift`:

```swift
import SwiftUI

struct MessageContentView: View {
    let content: String

    var body: some View {
        let blocks = ContentParser.parse(content)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks, id: \.id) { block in
                blockView(for: block)
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: MessageBlock) -> some View {
        switch block {
        case .text(let attributedString):
            Text(attributedString)
                .textSelection(.enabled)

        case .inlineCode(let code):
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))

        case .codeBlock(let language, let code):
            CodeBlockView(code: code, language: language)

        case .fileReference(let path):
            FileReferenceView(path: path)

        case .image(let url):
            if url.isFileURL, let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit).frame(maxWidth: 400)
                } placeholder: {
                    ProgressView()
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: build command
Expected: BUILD SUCCEEDED (note: `FileReferenceView` doesn't exist yet — this step should be done after Task 6, OR create a minimal stub. Create the stub first:)

If build fails because `FileReferenceView` doesn't exist, create a temporary stub:

```swift
// Temporary stub — replaced in Task 6
struct FileReferenceView: View {
    let path: String
    var body: some View { Text(path) }
}
```

Put the stub at the bottom of `MessageContentView.swift` temporarily. It will be replaced with the real implementation in Task 6.

- [ ] **Step 3: Commit**

```bash
cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard"
git add ClaudeDashboard/Views/Chat/MessageContentView.swift
git commit -m "feat: add MessageContentView for block-based message rendering"
```

---

## Task 6: FileReferenceView

**Files:**
- Create: `ClaudeDashboard/Views/Chat/FileReferenceView.swift`
- Modify: `ClaudeDashboard/Views/Chat/MessageContentView.swift` (remove stub if added)

- [ ] **Step 1: Write FileReferenceView**

Create `ClaudeDashboard/Views/Chat/FileReferenceView.swift`:

```swift
import SwiftUI
import PDFKit

struct FileReferenceView: View {
    let path: String
    @State private var isExpanded = false
    @State private var fileExists = false

    private var fileName: String { (path as NSString).lastPathComponent }
    private var fileExtension: String { (path as NSString).pathExtension.lowercased() }

    var body: some View {
        Group {
            if fileExists {
                VStack(alignment: .leading, spacing: 4) {
                    chipButton
                    if isExpanded {
                        expandedContent
                    }
                }
            } else {
                // Non-existent file: render as plain text
                Text(path)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            // Check on the outer body so fileExists is set before first render decision
            fileExists = FileManager.default.fileExists(atPath: path)
        }
    }

    private var chipButton: some View {
        Button {
            withAnimation(.spring(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.caption)
                Text(fileName)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        let type = FileAttachment.fileType(for: fileName)
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.text"
        case .other: return "doc"
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        let type = FileAttachment.fileType(for: fileName)
        switch type {
        case .code, .text:
            if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                let lang = type == .code ? fileExtension : nil
                CodeBlockView(code: String(contents.prefix(10_000)), language: lang)
            } else {
                errorView("Unable to read file")
            }

        case .image:
            if let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                errorView("Unable to load image")
            }

        case .pdf:
            PDFPreviewView(url: URL(fileURLWithPath: path))
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 8))

        case .other:
            fileMetadataView
        }
    }

    private var fileMetadataView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
                if let size = attrs[.size] as? Int64 {
                    Text("Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                        .font(.caption)
                }
                if let date = attrs[.modificationDate] as? Date {
                    Text("Modified: \(date.formatted())")
                        .font(.caption)
                }
            }
            Button("Open in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.accent)
        }
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func errorView(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(8)
    }
}

/// Wraps PDFKit.PDFView for inline PDF preview
struct PDFPreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFKit.PDFView, context: Context) {}
}
```

- [ ] **Step 2: Remove FileReferenceView stub from MessageContentView.swift if present**

If a `FileReferenceView` stub was added in Task 5, remove it now.

- [ ] **Step 3: Build to verify it compiles**

Run: build command
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard"
git add ClaudeDashboard/Views/Chat/FileReferenceView.swift
git add ClaudeDashboard/Views/Chat/MessageContentView.swift  # only if stub was removed
git commit -m "feat: add FileReferenceView with expand/collapse inline preview"
```

---

## Task 7: Wire Up MessageBubbleView

**Files:**
- Modify: `ClaudeDashboard/Views/Chat/MessageBubbleView.swift`
- Create: `ClaudeDashboard/Views/Chat/AttachmentChipView.swift`

- [ ] **Step 1: Create AttachmentChipView**

Create `ClaudeDashboard/Views/Chat/AttachmentChipView.swift`:

```swift
import SwiftUI

struct AttachmentChipView: View {
    let attachment: FileAttachment
    var onRemove: (() -> Void)? = nil
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let thumbnail = attachment.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: iconName)
                        .font(.caption)
                }
                Text(attachment.fileName)
                    .font(.caption)
                    .lineLimit(1)
                Text(ByteCountFormatter.string(fromByteCount: attachment.fileSize, countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if let onRemove {
                    Button { onRemove() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.spring(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(Capsule())

            // Show inline preview directly — don't nest FileReferenceView (which has its own chip)
            if isExpanded {
                attachmentPreview
            }
        }
    }

    @ViewBuilder
    private var attachmentPreview: some View {
        let path = attachment.url.path
        switch attachment.fileType {
        case .code, .text:
            if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                let lang = attachment.fileType == .code ? (attachment.fileName as NSString).pathExtension : nil
                CodeBlockView(code: String(contents.prefix(10_000)), language: lang)
            }
        case .image:
            if let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        case .pdf:
            PDFPreviewView(url: attachment.url)
                .frame(height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case .other:
            Text("No preview available")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var iconName: String {
        switch attachment.fileType {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .text: return "doc.text"
        case .other: return "doc"
        }
    }
}
```

- [ ] **Step 2: Update MessageBubbleView**

Replace the body of `ClaudeDashboard/Views/Chat/MessageBubbleView.swift`:

```swift
import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 80) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    // Attachment chips (if any)
                    if !message.attachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(message.attachments) { attachment in
                                    AttachmentChipView(attachment: attachment)
                                }
                            }
                        }
                    }

                    // Rich message content
                    MessageContentView(content: message.content)
                }
                .padding(12)
                .if(message.role == .user) { view in
                    view.glassEffect(.regular.tint(.accentColor.opacity(0.3)).interactive(), in: .rect(cornerRadii: .init(topLeading: 16, bottomLeading: 16, bottomTrailing: 4, topTrailing: 16)))
                }
                .if(message.role == .assistant) { view in
                    view.glassEffect(.regular.interactive(), in: .rect(cornerRadii: .init(topLeading: 16, bottomLeading: 4, bottomTrailing: 16, topTrailing: 16)))
                }
                if let out = message.tokensOut, out > 0 {
                    Text("\(out) tokens").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            if message.role == .assistant { Spacer(minLength: 80) }
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition { transform(self) } else { self }
    }
}
```

- [ ] **Step 3: Build and verify**

Run: build command
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run all tests to verify nothing broke**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' test 2>&1 | grep -E "(Test Suite|passed|failed)" | head -10`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard"
git add ClaudeDashboard/Views/Chat/AttachmentChipView.swift ClaudeDashboard/Views/Chat/MessageBubbleView.swift
git commit -m "feat: wire up rich content rendering in MessageBubbleView"
```

---

## Task 8: Drag-and-Drop Attachments in MessageInputView

**Files:**
- Modify: `ClaudeDashboard/ViewModels/ChatViewModel.swift`
- Modify: `ClaudeDashboard/Views/Chat/MessageInputView.swift`

- [ ] **Step 1: Add pending attachments to ChatViewModel**

Add to `ClaudeDashboard/ViewModels/ChatViewModel.swift`:

```swift
// Add these properties after the existing property declarations:
var pendingAttachments: [FileAttachment] = []
var attachmentError: String?

// Add these methods:

func addAttachment(url: URL) {
    guard pendingAttachments.count < FileAttachment.maxFileCount else {
        attachmentError = "Maximum \(FileAttachment.maxFileCount) files per message"
        return
    }

    guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
          let fileSize = attrs[.size] as? Int64 else {
        attachmentError = "Cannot read file: \(url.lastPathComponent)"
        return
    }

    guard FileAttachment.isWithinSizeLimit(bytes: fileSize) else {
        attachmentError = "\(url.lastPathComponent) exceeds 1MB limit"
        return
    }

    let totalSize = pendingAttachments.reduce(Int64(0)) { $0 + $1.fileSize } + fileSize
    guard totalSize <= FileAttachment.maxTotalSize else {
        attachmentError = "Total attachment size exceeds 5MB limit"
        return
    }

    let fileName = url.lastPathComponent
    let fileType = FileAttachment.fileType(for: fileName)

    var thumbnailData: Data? = nil
    if fileType == .image, let image = NSImage(contentsOf: url) {
        let maxDim: CGFloat = 40
        let ratio = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
        let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        thumb.unlockFocus()
        if let tiffData = thumb.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiffData) {
            thumbnailData = rep.representation(using: .png, properties: [:])
        }
    }

    let attachment = FileAttachment(
        id: UUID(),
        url: url,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
        thumbnailData: thumbnailData
    )
    pendingAttachments.append(attachment)
    attachmentError = nil
}

func removeAttachment(_ attachment: FileAttachment) {
    pendingAttachments.removeAll { $0.id == attachment.id }
    attachmentError = nil
}
```

- [ ] **Step 2: Update sendMessage() to handle attachments**

Modify `sendMessage()` in `ChatViewModel.swift`:

```swift
func sendMessage() {
    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }

    let attachments = pendingAttachments

    // Capture values before async work to avoid race conditions
    let model = modelChanged ? selectedModel : nil
    let effort = effortChanged ? selectedEffort : nil

    // Update UI state immediately
    messages.append(ChatMessage(role: .user, content: text, attachments: attachments))
    inputText = ""
    pendingAttachments = []
    attachmentError = nil
    isWaitingForResponse = true
    messageCount += 1
    if sessionStartTime == nil {
        sessionStartTime = Date()
    }

    if !attachments.isEmpty {
        // Read file contents off the main thread, then send on MainActor
        Task {
            let fileContents: [String] = await Task.detached {
                attachments.compactMap { attachment in
                    guard let content = try? String(contentsOf: attachment.url, encoding: .utf8) else { return nil }
                    let lang = (attachment.fileName as NSString).pathExtension
                    return "```\(lang) (\(attachment.fileName))\n\(content)\n```"
                }
            }.value

            let fullText = fileContents.isEmpty ? text : fileContents.joined(separator: "\n\n") + "\n\n" + text
            cliService.sendMessage(fullText, model: model, effort: effort)
        }
    } else {
        cliService.sendMessage(text, model: model, effort: effort)
    }
}
```

- [ ] **Step 3: Update newConversation() to clear attachment state**

In `ChatViewModel.swift`, add to the `newConversation()` method:

```swift
func newConversation() {
    cliService.newSession()
    messages.removeAll()
    rawOutput.removeAll()
    sessionInputTokens = 0
    sessionOutputTokens = 0
    sessionCacheTokens = 0
    messageCount = 0
    sessionStartTime = nil
    isWaitingForResponse = false
    pendingAttachments = []   // new
    attachmentError = nil     // new
}
```

- [ ] **Step 4: Update MessageInputView with drop zone and paperclip**

Replace `ClaudeDashboard/Views/Chat/MessageInputView.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct MessageInputView: View {
    @Bindable var viewModel: ChatViewModel

    private let models = ["opus", "sonnet", "haiku"]
    private let efforts = ["low", "medium", "high", "max"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Attachment chips row
            if !viewModel.pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.pendingAttachments) { attachment in
                            AttachmentChipView(attachment: attachment) {
                                viewModel.removeAttachment(attachment)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            // Error message
            if let error = viewModel.attachmentError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
            }

            // Input row
            HStack(alignment: .bottom, spacing: 8) {
                Menu {
                    ForEach(models, id: \.self) { model in
                        Button {
                            viewModel.selectedModel = model
                            viewModel.modelChanged = true
                        } label: {
                            HStack {
                                Text(model.capitalized)
                                if viewModel.selectedModel == model {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "cpu").font(.caption)
                        Text(viewModel.selectedModel.capitalized).font(.caption2)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Menu {
                    ForEach(efforts, id: \.self) { effort in
                        Button {
                            viewModel.selectedEffort = effort
                            viewModel.effortChanged = true
                        } label: {
                            HStack {
                                Text(effort.capitalized)
                                if viewModel.selectedEffort == effort {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "gauge.medium").font(.caption)
                        Text(viewModel.selectedEffort.capitalized).font(.caption2)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Paperclip button
                Button { pickFiles() } label: {
                    Image(systemName: "paperclip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Attach files")

                TextField("Message Claude...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...10)
                    .onSubmit {
                        if !NSEvent.modifierFlags.contains(.shift) { viewModel.sendMessage() }
                    }

                Button { viewModel.sendMessage() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                        .foregroundStyle(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isWaitingForResponse)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .padding(.leading, 16).padding(.bottom, 12)
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                viewModel.addAttachment(url: url)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    viewModel.addAttachment(url: url)
                }
            }
        }
        return true
    }
}
```

- [ ] **Step 5: Build and run all tests**

Run: build + test commands
Expected: BUILD SUCCEEDED, all tests pass

- [ ] **Step 6: Commit**

```bash
cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard"
git add ClaudeDashboard/ViewModels/ChatViewModel.swift ClaudeDashboard/Views/Chat/MessageInputView.swift
git commit -m "feat: add drag-and-drop file attachments with paperclip picker"
```

---

## Task 9: Final Integration Test & Cleanup

**Files:**
- All files from previous tasks

- [ ] **Step 1: Full build**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run all tests**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' test 2>&1 | grep -E "(Test Suite|passed|failed|error:)" | head -20`
Expected: All test suites pass

- [ ] **Step 3: Verify no compiler warnings related to new files**

Run: `cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard" && xcodebuild -project ClaudeDashboard.xcodeproj -scheme ClaudeDashboard -destination 'platform=macOS' build 2>&1 | grep "warning:" | grep -E "(ContentParser|SyntaxHighlighter|MessageContent|CodeBlock|FileReference|AttachmentChip|FileAttachment)" | head -10`
Expected: No warnings from new files

- [ ] **Step 4: Final commit if any cleanup was needed**

```bash
cd "/Users/alexstanage/Documents/Code Projects/MacOS Projects/ClaudeDashboard"
# Only if there were fixes:
git add -A
git commit -m "fix: address build warnings and cleanup from file embedding feature"
```
