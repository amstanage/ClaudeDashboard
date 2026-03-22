import Foundation

struct SessionStats {
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var model: String?
    var firstMessage: String?
}

struct JSONLReader {

    /// Parse a Claude Code JSONL session file.
    /// The stored format differs from the streaming JSON:
    /// - assistant messages: {"parentUuid":..., "message":{"role":"assistant","content":[...],"usage":{...},"model":...}}
    /// - user messages: {"type":"user","message":{"role":"user","content":[...]}} or {"type":"queue-operation","content":"..."}
    func readFile(at url: URL) throws -> [CLIEvent] {
        let content = try String(contentsOf: url, encoding: .utf8)
        var events: [CLIEvent] = []

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { continue }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

            // Try to extract the message object
            guard let message = json["message"] as? [String: Any] else {
                // queue-operation events have "content" at top level (the user's prompt)
                if let type = json["type"] as? String, type == "queue-operation",
                   let content = json["content"] as? String {
                    let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanContent.isEmpty {
                        events.append(CLIEvent(
                            type: "user",
                            message: CLIEvent.CLIMessage(role: "user", content: [CLIEvent.ContentBlock(type: "text", text: cleanContent)], usage: nil, model: nil),
                            result: nil, subtype: nil, sessionId: nil, usage: nil
                        ))
                    }
                }
                continue
            }

            let role = message["role"] as? String ?? ""
            let model = message["model"] as? String

            // Parse content blocks
            var contentBlocks: [CLIEvent.ContentBlock] = []
            if let contentArr = message["content"] as? [[String: Any]] {
                for block in contentArr {
                    let blockType = block["type"] as? String ?? "text"
                    let text = block["text"] as? String
                    contentBlocks.append(CLIEvent.ContentBlock(type: blockType, text: text))
                }
            }

            // Parse usage
            var usage: CLIEvent.TokenUsage? = nil
            if let usageDict = message["usage"] as? [String: Any] {
                let inputTokens = usageDict["input_tokens"] as? Int ?? 0
                let outputTokens = usageDict["output_tokens"] as? Int ?? 0
                let cacheCreation = usageDict["cache_creation_input_tokens"] as? Int
                let cacheRead = usageDict["cache_read_input_tokens"] as? Int
                usage = CLIEvent.TokenUsage(
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheCreationInputTokens: cacheCreation,
                    cacheReadInputTokens: cacheRead
                )
            }

            let eventType = role == "assistant" ? "assistant" : (role == "user" ? "user" : (json["type"] as? String ?? "unknown"))

            events.append(CLIEvent(
                type: eventType,
                message: CLIEvent.CLIMessage(role: role, content: contentBlocks.isEmpty ? nil : contentBlocks, usage: usage, model: model),
                result: nil, subtype: nil, sessionId: nil, usage: nil
            ))
        }

        return events
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

            // Get direct JSONL files (skip subdirectories like "subagents/")
            let files = (try? fm.contentsOfDirectory(at: projectDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))?
                .filter { $0.pathExtension == "jsonl" } ?? []

            for file in files {
                let sessionId = file.deletingPathExtension().lastPathComponent
                let events = (try? readFile(at: file)) ?? []
                let stats = extractSessionStats(from: events)

                // Skip sessions with no data
                guard stats.totalInputTokens > 0 || stats.totalOutputTokens > 0 || stats.firstMessage != nil else { continue }

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
