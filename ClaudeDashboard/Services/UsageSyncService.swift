import Foundation

@Observable
final class UsageSyncService: @unchecked Sendable {
    private let reader = JSONLReader()
    private var db: DatabaseService?
    private var eventStream: FSEventStreamRef?
    private(set) var isSyncing = false
    private(set) var syncProgress: Double = 0

    private var claudeProjectsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    func configure(database: DatabaseService) {
        self.db = database
    }

    func performInitialSync() async throws {
        guard let db else { return }
        isSyncing = true
        defer { isSyncing = false }

        let fm = FileManager.default
        guard fm.fileExists(atPath: claudeProjectsURL.path) else { return }

        let sessions = try reader.scanProjectsDirectory(at: claudeProjectsURL)
        let total = Double(sessions.count)

        for (index, session) in sessions.enumerated() {
            // Skip sessions the user has deleted
            if (try? db.isSessionHidden(id: session.id)) == true {
                syncProgress = Double(index + 1) / total
                continue
            }
            try db.insertSession(session)
            syncProgress = Double(index + 1) / total
        }

        try rebuildDailyStats()
    }

    private func rebuildDailyStats() throws {
        guard let db else { return }
        let sessions = try db.fetchAllSessions(limit: 10000)

        var dailyMap: [String: (input: Int, output: Int, count: Int)] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for session in sessions {
            let key = formatter.string(from: session.startedAt)
            var existing = dailyMap[key] ?? (0, 0, 0)
            existing.input += session.totalInputTokens
            existing.output += session.totalOutputTokens
            existing.count += 1
            dailyMap[key] = existing
        }

        for (dateStr, stats) in dailyMap {
            if let date = formatter.date(from: dateStr) {
                try db.upsertDailyStats(date: date, inputTokens: stats.input, outputTokens: stats.output, sessions: stats.count)
            }
        }
    }

    func startWatching() {
        let path = claudeProjectsURL.path as CFString
        let pathsToWatch = [path] as CFArray

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        eventStream = FSEventStreamCreate(
            nil,
            { (_, info, numEvents, eventPaths, _, _) in
                guard let info else { return }
                let service = Unmanaged<UsageSyncService>.fromOpaque(info).takeUnretainedValue()
                Task { try? await service.handleFileChange() }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )

        if let stream = eventStream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
        }
    }

    func stopWatching() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    private func handleFileChange() async throws {
        try await performInitialSync()
    }
}
