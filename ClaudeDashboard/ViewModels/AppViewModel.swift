import SwiftUI

@Observable
final class AppViewModel {
    var currentModel: String = "Claude Opus 4.6"
    var effortLevel: String = "max"
    var sessionTokens: Int = 0
    var dailyTokens: Int = 0
    var sessionStartTime: Date? = nil

    private(set) var database: DatabaseService?
    private let syncService = UsageSyncService()

    var sessionDuration: String {
        guard let start = sessionStartTime else { return "—" }
        let elapsed = Date().timeIntervalSince(start)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    @MainActor func bootstrap() async {
        let dbURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClaudeDashboard/usage.db")
        do {
            database = try DatabaseService(url: dbURL)
            syncService.configure(database: database!)
            try await syncService.performInitialSync()
            syncService.startWatching()
        } catch {
            print("Database init failed: \(error). Attempting recreation...")
            try? FileManager.default.removeItem(at: dbURL)
            database = try? DatabaseService(url: dbURL)
        }
    }
}
