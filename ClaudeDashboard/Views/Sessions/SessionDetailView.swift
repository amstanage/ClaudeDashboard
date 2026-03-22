import SwiftUI

private struct MessageRow: Identifiable {
    let id: Int
    let isUser: Bool
    let text: String
}

struct SessionDetailView: View {
    let session: SessionRecord
    @State private var messages: [MessageRow] = []
    @State private var isLoading = false
    @State private var totalMessageCount = 0

    private static let maxPreviewMessages = 20
    private static let maxTextLength = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(session.model ?? "Unknown", systemImage: "cpu").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(session.totalTokens) tokens").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            if isLoading {
                ProgressView("Loading conversation...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if messages.isEmpty {
                Text("No messages found.").foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(messages) { row in
                        HStack(alignment: .top, spacing: 8) {
                            Text(row.isUser ? "You:" : "Claude:")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(row.isUser ? Color.primary : Color.cyan)
                                .frame(width: 50, alignment: .trailing)
                            Text(row.text)
                                .font(.callout)
                                .lineLimit(12)
                        }
                    }
                }
                .textSelection(.enabled)
                if totalMessageCount > Self.maxPreviewMessages {
                    Text("\(totalMessageCount - Self.maxPreviewMessages) more messages...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .task(id: session.id) { await loadMessages() }
    }

    private func loadMessages() async {
        isLoading = true
        messages = []
        let sessionId = session.id
        let maxMessages = Self.maxPreviewMessages
        let maxLen = Self.maxTextLength
        let reader = JSONLReader()
        let (loaded, total): ([MessageRow], Int) = await Task.detached {
            let claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
            guard let projectDirs = try? FileManager.default.contentsOfDirectory(at: claudeDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return ([], 0) }
            for dir in projectDirs {
                let file = dir.appendingPathComponent("\(sessionId).jsonl")
                if FileManager.default.fileExists(atPath: file.path) {
                    let events: [CLIEvent] = (try? reader.readFile(at: file)) ?? []
                    let allRows = events.enumerated().compactMap { index, event -> MessageRow? in
                        guard let text = event.textContent, !text.isEmpty else { return nil }
                        let truncated = text.count > maxLen ? String(text.prefix(maxLen)) + "..." : text
                        return MessageRow(id: index, isUser: event.type == "user", text: truncated)
                    }
                    let preview = Array(allRows.prefix(maxMessages))
                    return (preview, allRows.count)
                }
            }
            return ([], 0)
        }.value
        messages = loaded
        totalMessageCount = total
        isLoading = false
    }
}
