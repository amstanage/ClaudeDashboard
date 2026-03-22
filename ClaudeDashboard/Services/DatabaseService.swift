import Foundation
import SQLite3

final class DatabaseService {
    private var db: OpaquePointer?

    init(url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        try createTables()
    }

    deinit { sqlite3_close(db) }

    private func createTables() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY, project_path TEXT, started_at INTEGER, ended_at INTEGER,
            model TEXT, total_input_tokens INTEGER DEFAULT 0, total_output_tokens INTEGER DEFAULT 0, first_message TEXT
        );
        CREATE TABLE IF NOT EXISTS daily_stats (
            date TEXT PRIMARY KEY, total_input_tokens INTEGER DEFAULT 0,
            total_output_tokens INTEGER DEFAULT 0, session_count INTEGER DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT REFERENCES sessions(id),
            role TEXT, content TEXT, tokens_in INTEGER DEFAULT 0, tokens_out INTEGER DEFAULT 0, model TEXT, timestamp INTEGER
        );
        CREATE TABLE IF NOT EXISTS sync_state (file_path TEXT PRIMARY KEY, last_synced_at INTEGER);
        CREATE TABLE IF NOT EXISTS hidden_sessions (id TEXT PRIMARY KEY);
        """
        try execute(sql)
        try migrate()
    }

    private func migrate() throws {
        // Add total_cache_tokens columns if missing
        let addColumn = { [self] (table: String) in
            let pragma: [String] = try query("PRAGMA table_info(\(table));") { stmt in
                String(cString: sqlite3_column_text(stmt, 1))
            }
            if !pragma.contains("total_cache_tokens") {
                try execute("ALTER TABLE \(table) ADD COLUMN total_cache_tokens INTEGER DEFAULT 0;")
            }
        }
        try addColumn("sessions")
        try addColumn("daily_stats")
    }

    func insertSession(_ session: SessionRecord) throws {
        let sql = "INSERT OR REPLACE INTO sessions (id, project_path, started_at, ended_at, model, total_input_tokens, total_output_tokens, total_cache_tokens, first_message) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);"
        try execute(sql, bindings: [
            .text(session.id), .text(session.projectPath),
            .int(Int(session.startedAt.timeIntervalSince1970)),
            .optionalInt(session.endedAt.map { Int($0.timeIntervalSince1970) }),
            .optionalText(session.model), .int(session.totalInputTokens),
            .int(session.totalOutputTokens), .int(session.totalCacheTokens),
            .optionalText(session.firstMessage),
        ])
    }

    private static let sessionColumns = "id, project_path, started_at, ended_at, model, total_input_tokens, total_output_tokens, first_message, total_cache_tokens"

    private static func parseSession(from stmt: OpaquePointer?) -> SessionRecord {
        SessionRecord(
            id: String(cString: sqlite3_column_text(stmt, 0)),
            projectPath: String(cString: sqlite3_column_text(stmt, 1)),
            startedAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 2))),
            endedAt: sqlite3_column_type(stmt, 3) != SQLITE_NULL ? Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 3))) : nil,
            model: sqlite3_column_type(stmt, 4) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 4)) : nil,
            totalInputTokens: Int(sqlite3_column_int64(stmt, 5)),
            totalOutputTokens: Int(sqlite3_column_int64(stmt, 6)),
            totalCacheTokens: Int(sqlite3_column_int64(stmt, 8)),
            firstMessage: sqlite3_column_type(stmt, 7) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 7)) : nil
        )
    }

    func fetchSessions(limit: Int = 100) throws -> [SessionRecord] {
        let sql = "SELECT \(Self.sessionColumns) FROM sessions WHERE id NOT IN (SELECT id FROM hidden_sessions) ORDER BY started_at DESC LIMIT ?;"
        return try query(sql, bindings: [.int(limit)]) { Self.parseSession(from: $0) }
    }

    func searchSessions(query: String) throws -> [SessionRecord] {
        let sql = "SELECT \(Self.sessionColumns) FROM sessions WHERE first_message LIKE ? AND id NOT IN (SELECT id FROM hidden_sessions) ORDER BY started_at DESC;"
        return try self.query(sql, bindings: [.text("%\(query)%")]) { Self.parseSession(from: $0) }
    }

    func deleteSession(id: String) throws {
        try execute("INSERT OR IGNORE INTO hidden_sessions (id) VALUES (?);", bindings: [.text(id)])
    }

    func deleteAllSessions() throws {
        try execute("INSERT OR IGNORE INTO hidden_sessions (id) SELECT id FROM sessions;")
    }

    /// Fetch all sessions including hidden ones — used for usage stats aggregation
    func fetchAllSessions(limit: Int = 10000) throws -> [SessionRecord] {
        let sql = "SELECT \(Self.sessionColumns) FROM sessions ORDER BY started_at DESC LIMIT ?;"
        return try query(sql, bindings: [.int(limit)]) { Self.parseSession(from: $0) }
    }

    func isSessionHidden(id: String) throws -> Bool {
        let results: [Bool] = try query("SELECT 1 FROM hidden_sessions WHERE id = ?;", bindings: [.text(id)]) { _ in true }
        return !results.isEmpty
    }

    func upsertDailyStats(date: Date, inputTokens: Int, outputTokens: Int, cacheTokens: Int, sessions: Int) throws {
        let dateStr = Self.dateFormatter.string(from: date)
        let sql = "INSERT OR REPLACE INTO daily_stats (date, total_input_tokens, total_output_tokens, total_cache_tokens, session_count) VALUES (?, ?, ?, ?, ?);"
        try execute(sql, bindings: [.text(dateStr), .int(inputTokens), .int(outputTokens), .int(cacheTokens), .int(sessions)])
    }

    func fetchDailyStats(from startDate: Date, to endDate: Date) throws -> [DailyStats] {
        let startStr = Self.dateFormatter.string(from: startDate)
        let endStr = Self.dateFormatter.string(from: endDate)
        let sql = "SELECT date, total_input_tokens, total_output_tokens, total_cache_tokens, session_count FROM daily_stats WHERE date >= ? AND date <= ? ORDER BY date ASC;"
        return try query(sql, bindings: [.text(startStr), .text(endStr)]) { stmt in
            let dateStr = String(cString: sqlite3_column_text(stmt, 0))
            return DailyStats(
                date: Self.dateFormatter.date(from: dateStr) ?? Date(),
                totalInputTokens: Int(sqlite3_column_int64(stmt, 1)),
                totalOutputTokens: Int(sqlite3_column_int64(stmt, 2)),
                totalCacheTokens: Int(sqlite3_column_int64(stmt, 3)),
                sessionCount: Int(sqlite3_column_int64(stmt, 4))
            )
        }
    }

    func lastSyncedAt(for filePath: String) throws -> Date? {
        let sql = "SELECT last_synced_at FROM sync_state WHERE file_path = ?;"
        let results: [Date] = try query(sql, bindings: [.text(filePath)]) { stmt in
            Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 0)))
        }
        return results.first
    }

    func updateSyncState(filePath: String, syncedAt: Date) throws {
        let sql = "INSERT OR REPLACE INTO sync_state (file_path, last_synced_at) VALUES (?, ?);"
        try execute(sql, bindings: [.text(filePath), .int(Int(syncedAt.timeIntervalSince1970))])
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private enum Binding {
        case text(String), int(Int), optionalText(String?), optionalInt(Int?)
    }

    private func execute(_ sql: String, bindings: [Binding] = []) throws {
        if bindings.isEmpty {
            var errMsg: UnsafeMutablePointer<CChar>?
            guard sqlite3_exec(db, sql, nil, nil, &errMsg) == SQLITE_OK else {
                let msg = errMsg.map { String(cString: $0) } ?? "unknown"
                sqlite3_free(errMsg)
                throw DatabaseError.executeFailed(msg)
            }
            return
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        for (i, binding) in bindings.enumerated() {
            let idx = Int32(i + 1)
            switch binding {
            case .text(let s): sqlite3_bind_text(stmt, idx, s, -1, Self.SQLITE_TRANSIENT)
            case .int(let n): sqlite3_bind_int64(stmt, idx, Int64(n))
            case .optionalText(let s):
                if let s { sqlite3_bind_text(stmt, idx, s, -1, Self.SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, idx) }
            case .optionalInt(let n):
                if let n { sqlite3_bind_int64(stmt, idx, Int64(n)) } else { sqlite3_bind_null(stmt, idx) }
            }
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.stepFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query<T>(_ sql: String, bindings: [Binding] = [], row: (OpaquePointer) -> T) throws -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        for (i, binding) in bindings.enumerated() {
            let idx = Int32(i + 1)
            switch binding {
            case .text(let s): sqlite3_bind_text(stmt, idx, s, -1, Self.SQLITE_TRANSIENT)
            case .int(let n): sqlite3_bind_int64(stmt, idx, Int64(n))
            case .optionalText(let s):
                if let s { sqlite3_bind_text(stmt, idx, s, -1, Self.SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, idx) }
            case .optionalInt(let n):
                if let n { sqlite3_bind_int64(stmt, idx, Int64(n)) } else { sqlite3_bind_null(stmt, idx) }
            }
        }
        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW { results.append(row(stmt!)) }
        return results
    }
}

enum DatabaseError: Error {
    case openFailed(String), executeFailed(String), prepareFailed(String), stepFailed(String)
}
