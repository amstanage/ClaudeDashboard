import XCTest
@testable import Claude_Dashboard

final class JSONLReaderTests: XCTestCase {
    var reader: JSONLReader!
    var fixtureURL: URL!

    override func setUp() {
        reader = JSONLReader()
        fixtureURL = Bundle(for: type(of: self)).url(forResource: "sample-session", withExtension: "jsonl")!
    }

    func testReadSessionFile() throws {
        let events = try reader.readFile(at: fixtureURL)
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events[0].type, "user")
        XCTAssertEqual(events[1].type, "assistant")
    }

    func testExtractSessionStats() throws {
        let events = try reader.readFile(at: fixtureURL)
        let stats = reader.extractSessionStats(from: events)
        XCTAssertEqual(stats.totalInputTokens, 40)
        XCTAssertEqual(stats.totalOutputTokens, 16)
        XCTAssertEqual(stats.model, "claude-opus-4-6")
        XCTAssertEqual(stats.firstMessage, "What is 2 + 2?")
    }

    func testExtractSessionStatsEmptyFile() throws {
        let stats = reader.extractSessionStats(from: [])
        XCTAssertEqual(stats.totalInputTokens, 0)
        XCTAssertEqual(stats.totalOutputTokens, 0)
        XCTAssertNil(stats.model)
        XCTAssertNil(stats.firstMessage)
    }

    func testScanProjectsDirectory() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("jsonl-test-\(UUID().uuidString)")
        let projectDir = tmpDir.appendingPathComponent("-Users-test-myproject")
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let sessionFile = projectDir.appendingPathComponent("abc123.jsonl")
        try FileManager.default.copyItem(at: fixtureURL, to: sessionFile)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let sessions = try reader.scanProjectsDirectory(at: tmpDir)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, "abc123")
        XCTAssertEqual(sessions[0].projectPath, "/Users/test/myproject")
        XCTAssertEqual(sessions[0].totalInputTokens, 40)
    }
}
