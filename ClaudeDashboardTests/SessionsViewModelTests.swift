import XCTest
@testable import Claude_Dashboard

@MainActor
final class SessionsViewModelTests: XCTestCase {
    var db: DatabaseService!
    var dbURL: URL!

    override func setUpWithError() throws {
        dbURL = FileManager.default.temporaryDirectory.appendingPathComponent("sess-test-\(UUID().uuidString).db")
        db = try DatabaseService(url: dbURL)
        try db.insertSession(SessionRecord(id: "s1", projectPath: "/p", startedAt: Date(), endedAt: nil, model: "claude-opus-4-6", totalInputTokens: 100, totalOutputTokens: 50, totalCacheTokens: 0, firstMessage: "Help with Swift"))
        try db.insertSession(SessionRecord(id: "s2", projectPath: "/p", startedAt: Date(), endedAt: nil, model: "claude-sonnet-4-6", totalInputTokens: 200, totalOutputTokens: 80, totalCacheTokens: 0, firstMessage: "Write Python script"))
    }

    override func tearDown() { db = nil; try? FileManager.default.removeItem(at: dbURL) }

    func testLoadSessions() async throws {
        let vm = SessionsViewModel()
        vm.configure(database: db)
        await vm.loadSessions()
        XCTAssertEqual(vm.filteredSessions.count, 2)
    }

    func testSearchFilters() async throws {
        let vm = SessionsViewModel()
        vm.configure(database: db)
        vm.searchQuery = "Swift"
        await vm.search()
        XCTAssertEqual(vm.filteredSessions.count, 1)
        XCTAssertEqual(vm.filteredSessions[0].id, "s1")
    }
}
