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
