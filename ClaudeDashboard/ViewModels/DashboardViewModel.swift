import SwiftUI

struct ModelUsageEntry: Identifiable {
    let model: String
    let totalTokens: Int
    var id: String { model }
    var displayName: String {
        model.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-", with: " ").capitalized
    }
    var color: Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .green }
        return .gray
    }
}

@MainActor @Observable
final class DashboardViewModel {
    var heatmapData: [DailyStats] = []
    var weeklyData: [DailyStats] = []
    var monthlyData: [DailyStats] = []
    var modelBreakdown: [ModelUsageEntry] = []
    var maxDailyTokens: Int = 0
    var modelPeriod: Int = 7

    private var db: DatabaseService?

    func configure(database: DatabaseService) { self.db = database }

    func loadAll() async {
        await loadHeatmapData()
        await loadWeeklyData()
        await loadMonthlyData()
        await loadModelBreakdown()
    }

    func loadHeatmapData() async {
        guard let db else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yearAgo = calendar.date(byAdding: .day, value: -364, to: today)!
        let fetched = (try? db.fetchDailyStats(from: yearAgo, to: today)) ?? []
        let fetchedByDate = Dictionary(uniqueKeysWithValues: fetched.map { (calendar.startOfDay(for: $0.date), $0) })
        var result: [DailyStats] = []
        for dayOffset in 0..<365 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: yearAgo)!
            let key = calendar.startOfDay(for: date)
            result.append(fetchedByDate[key] ?? DailyStats(date: date, totalInputTokens: 0, totalOutputTokens: 0, sessionCount: 0))
        }
        heatmapData = result
        maxDailyTokens = result.map(\.totalTokens).max() ?? 0
    }

    func loadWeeklyData() async {
        guard let db else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let fetched = (try? db.fetchDailyStats(from: weekStart, to: today)) ?? []
        let fetchedByDate = Dictionary(uniqueKeysWithValues: fetched.map { (calendar.startOfDay(for: $0.date), $0) })
        var result: [DailyStats] = []
        for dayOffset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let key = calendar.startOfDay(for: date)
            result.append(fetchedByDate[key] ?? DailyStats(date: date, totalInputTokens: 0, totalOutputTokens: 0, sessionCount: 0))
        }
        weeklyData = result
    }

    func loadMonthlyData() async {
        guard let db else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthAgo = calendar.date(byAdding: .day, value: -29, to: today)!
        let fetched = (try? db.fetchDailyStats(from: monthAgo, to: today)) ?? []
        let fetchedByDate = Dictionary(uniqueKeysWithValues: fetched.map { (calendar.startOfDay(for: $0.date), $0) })
        var result: [DailyStats] = []
        for dayOffset in 0..<30 {
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monthAgo)!
            let key = calendar.startOfDay(for: date)
            result.append(fetchedByDate[key] ?? DailyStats(date: date, totalInputTokens: 0, totalOutputTokens: 0, sessionCount: 0))
        }
        monthlyData = result
    }

    func loadModelBreakdown() async {
        guard let db else { return }
        let sessions = (try? db.fetchSessions(limit: 10000)) ?? []
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -modelPeriod, to: Date())!
        var modelMap: [String: Int] = [:]
        for session in sessions where session.startedAt >= cutoff {
            modelMap[session.model ?? "unknown", default: 0] += session.totalTokens
        }
        modelBreakdown = modelMap.map { ModelUsageEntry(model: $0.key, totalTokens: $0.value) }.sorted { $0.totalTokens > $1.totalTokens }
    }
}
