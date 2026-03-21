import Foundation

struct SessionStats {
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var model: String?
    var firstMessage: String?
    var startedAt: Date?
    var endedAt: Date?
}

struct JSONLReader {
    private let parser = CLIEventParser()

    func readFile(at url: URL) throws -> [CLIEvent] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parser.parseMultiple(lines: content)
    }

    func extractSessionStats(from events: [CLIEvent]) -> SessionStats {
        var stats = SessionStats()
        for event in events {
            if let usage = event.message?.usage {
                stats.totalInputTokens += usage.inputTokens
                stats.totalOutputTokens += usage.outputTokens
            }
            if stats.model == nil, let model = event.message?.model {
                stats.model = model
            }
            if stats.firstMessage == nil, event.type == "user" {
                stats.firstMessage = event.textContent
            }
        }
        return stats
    }

    func scanProjectsDirectory(at baseURL: URL) throws -> [SessionRecord] {
        let fm = FileManager.default
        var sessions: [SessionRecord] = []
        let projectDirs = try fm.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

        for projectDir in projectDirs {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: projectDir.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let projectPath = decodeProjectPath(projectDir.lastPathComponent)
            let files = try fm.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]).filter { $0.pathExtension == "jsonl" }

            for file in files {
                let sessionId = file.deletingPathExtension().lastPathComponent
                let events = (try? readFile(at: file)) ?? []
                let stats = extractSessionStats(from: events)
                let attrs = try? fm.attributesOfItem(atPath: file.path)
                let created = attrs?[.creationDate] as? Date ?? Date()
                let modified = attrs?[.modificationDate] as? Date ?? Date()

                sessions.append(SessionRecord(
                    id: sessionId, projectPath: projectPath, startedAt: created, endedAt: modified,
                    model: stats.model, totalInputTokens: stats.totalInputTokens,
                    totalOutputTokens: stats.totalOutputTokens, firstMessage: stats.firstMessage
                ))
            }
        }
        return sessions.sorted { $0.startedAt > $1.startedAt }
    }

    private func decodeProjectPath(_ encoded: String) -> String {
        guard encoded.hasPrefix("-") else { return encoded.removingPercentEncoding ?? encoded }
        return encoded.replacingOccurrences(of: "-", with: "/")
    }
}
