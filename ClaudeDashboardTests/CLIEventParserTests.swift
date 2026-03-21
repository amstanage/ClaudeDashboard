import XCTest
@testable import Claude_Dashboard

final class CLIEventParserTests: XCTestCase {

    var parser: CLIEventParser!

    override func setUp() {
        parser = CLIEventParser()
    }

    func testParseSingleEvent() throws {
        let json = """
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hello"}],"model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":5}}}
        """
        let event = try parser.parse(line: json)
        XCTAssertEqual(event.type, "assistant")
        XCTAssertEqual(event.textContent, "Hello")
        XCTAssertEqual(event.message?.model, "claude-opus-4-6")
        XCTAssertEqual(event.message?.usage?.inputTokens, 10)
        XCTAssertEqual(event.message?.usage?.outputTokens, 5)
        XCTAssertEqual(event.message?.usage?.totalTokens, 15)
    }

    func testParseUserEvent() throws {
        let json = """
        {"type":"user","message":{"role":"user","content":[{"type":"text","text":"Hi there"}]}}
        """
        let event = try parser.parse(line: json)
        XCTAssertEqual(event.type, "user")
        XCTAssertEqual(event.textContent, "Hi there")
        XCTAssertNil(event.message?.usage)
    }

    func testParseProgressEvent() throws {
        let json = """
        {"type":"progress","message":null}
        """
        let event = try parser.parse(line: json)
        XCTAssertEqual(event.type, "progress")
        XCTAssertNil(event.textContent)
    }

    func testParseInvalidJSON() {
        XCTAssertThrowsError(try parser.parse(line: "not json"))
    }

    func testParseMultipleLines() throws {
        let lines = """
        {"type":"user","message":{"role":"user","content":[{"type":"text","text":"Q1"}]}}
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"A1"}],"model":"claude-opus-4-6","usage":{"input_tokens":5,"output_tokens":3}}}
        """
        let events = try parser.parseMultiple(lines: lines)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].type, "user")
        XCTAssertEqual(events[1].type, "assistant")
    }
}
