import XCTest
@testable import Claude_Dashboard

@MainActor
final class DashboardViewModelTests: XCTestCase {
    var db: DatabaseService!
    var dbURL: URL!

    override func setUpWithError() throws {
        dbURL = FileManager.default.temporaryDirectory.appendingPathComponent("dash-test-\(UUID().uuidString).db")
        db = try DatabaseService(url: dbURL)
    }

    override func tearDown() {
        db = nil
        try? FileManager.default.removeItem(at: dbURL)
    }

    func testHeatmapDataReturns365Days() async throws {
        let vm = DashboardViewModel()
        vm.configure(database: db)
        await vm.loadHeatmapData()
        XCTAssertEqual(vm.heatmapData.count, 365)
    }

    func testWeeklyDataReturns7Days() async throws {
        let vm = DashboardViewModel()
        vm.configure(database: db)
        await vm.loadWeeklyData()
        XCTAssertEqual(vm.weeklyData.count, 7)
    }

    func testModelBreakdown() async throws {
        try db.insertSession(SessionRecord(id: "s1", projectPath: "/p", startedAt: Date(), endedAt: nil, model: "claude-opus-4-6", totalInputTokens: 1000, totalOutputTokens: 500, firstMessage: "test"))
        try db.insertSession(SessionRecord(id: "s2", projectPath: "/p", startedAt: Date(), endedAt: nil, model: "claude-sonnet-4-6", totalInputTokens: 500, totalOutputTokens: 250, firstMessage: "test"))
        let vm = DashboardViewModel()
        vm.configure(database: db)
        await vm.loadModelBreakdown()
        XCTAssertEqual(vm.modelBreakdown.count, 2)
        let opusEntry = vm.modelBreakdown.first { $0.model == "claude-opus-4-6" }
        XCTAssertNotNil(opusEntry)
        XCTAssertEqual(opusEntry?.totalTokens, 1500)
    }
}
