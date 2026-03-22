import XCTest
@testable import Claude_Dashboard

final class DatabaseServiceTests: XCTestCase {
    var db: DatabaseService!
    var dbURL: URL!

    override func setUpWithError() throws {
        dbURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).db")
        db = try DatabaseService(url: dbURL)
    }

    override func tearDown() {
        db = nil
        try? FileManager.default.removeItem(at: dbURL)
    }

    func testInsertAndFetchSession() throws {
        let session = SessionRecord(id: "test-1", projectPath: "/Users/test/project", startedAt: Date(timeIntervalSince1970: 1000), endedAt: Date(timeIntervalSince1970: 2000), model: "claude-opus-4-6", totalInputTokens: 100, totalOutputTokens: 50, totalCacheTokens: 0, firstMessage: "Hello")
        try db.insertSession(session)
        let fetched = try db.fetchSessions()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, "test-1")
        XCTAssertEqual(fetched[0].totalInputTokens, 100)
    }

    func testUpsertDailyStats() throws {
        let date = Date(timeIntervalSince1970: 86400)
        try db.upsertDailyStats(date: date, inputTokens: 100, outputTokens: 50, cacheTokens: 0, sessions: 1)
        try db.upsertDailyStats(date: date, inputTokens: 200, outputTokens: 80, cacheTokens: 0, sessions: 1)
        let stats = try db.fetchDailyStats(from: date, to: date)
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].totalInputTokens, 200)
    }

    func testFetchDailyStatsRange() throws {
        let day1 = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 86400))
        let day2 = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 86400 * 2))
        let day3 = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 86400 * 3))
        try db.upsertDailyStats(date: day1, inputTokens: 10, outputTokens: 5, cacheTokens: 0, sessions: 1)
        try db.upsertDailyStats(date: day2, inputTokens: 20, outputTokens: 10, cacheTokens: 0, sessions: 2)
        try db.upsertDailyStats(date: day3, inputTokens: 30, outputTokens: 15, cacheTokens: 0, sessions: 1)
        let stats = try db.fetchDailyStats(from: day1, to: day2)
        XCTAssertEqual(stats.count, 2)
    }

    func testSearchSessions() throws {
        let s1 = SessionRecord(id: "s1", projectPath: "/p", startedAt: Date(), endedAt: nil, model: "claude-opus-4-6", totalInputTokens: 10, totalOutputTokens: 5, totalCacheTokens: 0, firstMessage: "Help me with Swift")
        let s2 = SessionRecord(id: "s2", projectPath: "/p", startedAt: Date(), endedAt: nil, model: "claude-sonnet-4-6", totalInputTokens: 10, totalOutputTokens: 5, totalCacheTokens: 0, firstMessage: "Write Python code")
        try db.insertSession(s1)
        try db.insertSession(s2)
        let results = try db.searchSessions(query: "Swift")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "s1")
    }
}
