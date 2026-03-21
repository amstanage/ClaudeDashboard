import SwiftUI

@Observable
final class AppViewModel {
    var currentModel: String = "Claude Opus 4.6"
    var effortLevel: String = "max"
    var sessionInputTokens: Int = 0
    var sessionOutputTokens: Int = 0
    var dailyTokens: Int = 0
    var messageCount: Int = 0
    var sessionStartTime: Date? = nil

    private(set) var database: DatabaseService?
    private let syncService = UsageSyncService()

    var sessionTotalTokens: Int { sessionInputTokens + sessionOutputTokens }

    @MainActor func bootstrap() async {
        let dbURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClaudeDashboard/usage.db")
        do {
            database = try DatabaseService(url: dbURL)
            syncService.configure(database: database!)
            try await syncService.performInitialSync()
            syncService.startWatching()
            loadDailyTokens()
        } catch {
            print("Database init failed: \(error). Attempting recreation...")
            try? FileManager.default.removeItem(at: dbURL)
            database = try? DatabaseService(url: dbURL)
        }
    }

    func loadDailyTokens() {
        guard let database else { return }
        let today = Calendar.current.startOfDay(for: Date())
        if let stats = try? database.fetchDailyStats(from: today, to: today), let todayStats = stats.first {
            dailyTokens = todayStats.totalTokens
        }
    }
}
