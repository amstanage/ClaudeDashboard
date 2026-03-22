import Foundation
import os

private let logger = Logger(subsystem: "com.alexstanage.ClaudeDashboard", category: "UsageSyncService")

@Observable
final class UsageSyncService: @unchecked Sendable {
    private let reader = JSONLReader()
    private var db: DatabaseService?
    private var eventStream: FSEventStreamRef?
    private let watchQueue = DispatchQueue(label: "com.claudedashboard.fswatcher", qos: .utility)
    private let syncQueue = DispatchQueue(label: "com.claudedashboard.sync", qos: .utility)
    private(set) var isSyncing = false

    private var pendingSync = false
    private var lastSyncTime: Date = .distantPast
    private static let syncCooldown: TimeInterval = 10

    private var claudeProjectsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    func configure(database: DatabaseService) {
        self.db = database
    }

    deinit {
        stopWatching()
    }

    func performInitialSync() async throws {
        guard let db else {
            logger.warning("performInitialSync: no database configured")
            return
        }
        guard !isSyncing else {
            logger.info("performInitialSync: skipped, already syncing")
            return
        }
        isSyncing = true
        logger.info("performInitialSync: started")
        let start = CFAbsoluteTimeGetCurrent()

        defer {
            isSyncing = false
            lastSyncTime = Date()
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            logger.info("performInitialSync: finished in \(elapsed, format: .fixed(precision: 2))s")
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: claudeProjectsURL.path) else { return }

        // Do heavy file scanning off the main thread
        let url = claudeProjectsURL
        let reader = self.reader
        let sessions: [SessionRecord] = try await withCheckedThrowingContinuation { continuation in
            syncQueue.async {
                do {
                    let result = try reader.scanProjectsDirectory(at: url)
                    logger.info("scanProjectsDirectory: found \(result.count) sessions")
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        for session in sessions {
            if (try? db.isSessionHidden(id: session.id)) == true { continue }
            try db.insertSession(session)
        }

        try rebuildDailyStats()
    }

    private func rebuildDailyStats() throws {
        guard let db else { return }
        let sessions = try db.fetchAllSessions(limit: 10000)

        var dailyMap: [String: (input: Int, output: Int, cache: Int, count: Int)] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for session in sessions {
            let key = formatter.string(from: session.startedAt)
            var existing = dailyMap[key] ?? (0, 0, 0, 0)
            existing.input += session.totalInputTokens
            existing.output += session.totalOutputTokens
            existing.cache += session.totalCacheTokens
            existing.count += 1
            dailyMap[key] = existing
        }

        for (dateStr, stats) in dailyMap {
            if let date = formatter.date(from: dateStr) {
                try db.upsertDailyStats(date: date, inputTokens: stats.input, outputTokens: stats.output, cacheTokens: stats.cache, sessions: stats.count)
            }
        }
    }

    func startWatching() {
        stopWatching()

        let pathString = claudeProjectsURL.path
        let pathsToWatch = [pathString] as NSArray as CFArray

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        guard let stream = FSEventStreamCreate(
            nil,
            { (_, info, numEvents, _, _, _) in
                guard let info else { return }
                let service = Unmanaged<UsageSyncService>.fromOpaque(info).takeUnretainedValue()
                logger.debug("FSEvent callback: \(numEvents) events")
                Task { @MainActor in
                    service.scheduleSync()
                }
            },
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            5.0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
        ) else {
            logger.error("Failed to create FSEventStream")
            return
        }

        eventStream = stream
        FSEventStreamSetDispatchQueue(stream, watchQueue)
        FSEventStreamStart(stream)
        logger.info("startWatching: FSEventStream started for \(pathString)")
    }

    @MainActor
    private func scheduleSync() {
        let elapsed = Date().timeIntervalSince(lastSyncTime)
        if elapsed < Self.syncCooldown {
            guard !pendingSync else {
                logger.debug("scheduleSync: pending sync already queued, skipping")
                return
            }
            pendingSync = true
            let delay = Self.syncCooldown - elapsed
            logger.info("scheduleSync: cooldown active, scheduling in \(delay, format: .fixed(precision: 1))s")
            Task.detached { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self else { return }
                await MainActor.run {
                    self.pendingSync = false
                }
                try? await self.performInitialSync()
            }
            return
        }
        guard !isSyncing else {
            logger.info("scheduleSync: already syncing, marking pending")
            pendingSync = true
            return
        }
        logger.info("scheduleSync: starting sync now")
        Task.detached { [weak self] in
            try? await self?.performInitialSync()
        }
    }

    func stopWatching() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
            logger.info("stopWatching: FSEventStream stopped")
        }
    }
}
