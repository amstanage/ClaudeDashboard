import XCTest
import AppKit
@testable import Claude_Dashboard

final class SyntaxHighlighterTests: XCTestCase {
    func testSwiftKeywordsHighlighted() {
        let code = "let x = 1"
        let result = SyntaxHighlighter.highlight(code, language: "swift")
        let attrs = result.attributes(at: 0, effectiveRange: nil)
        let color = attrs[.foregroundColor] as? NSColor
        XCTAssertNotNil(color, "Keywords should have a foreground color")
    }

    func testStringLiteralsHighlighted() {
        let code = #"let name = "hello""#
        let result = SyntaxHighlighter.highlight(code, language: "swift")
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
