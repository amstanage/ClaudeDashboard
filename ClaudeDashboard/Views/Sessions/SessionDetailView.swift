import SwiftUI

struct SessionDetailView: View {
    let session: SessionRecord
    @State private var messages: [CLIEvent] = []
    private let reader = JSONLReader()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(session.model ?? "Unknown", systemImage: "cpu").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(session.totalTokens) tokens").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            if messages.isEmpty {
                Text("Loading conversation...").foregroundStyle(.tertiary)
            } else {
                ForEach(Array(messages.enumerated()), id: \.offset) { _, event in
                    if let text = event.textContent {
                        HStack(alignment: .top, spacing: 8) {
                            Text(event.type == "user" ? "You:" : "Claude:")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(event.type == "user" ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.cyan))
                                .frame(width: 50, alignment: .trailing)
                            Text(text).font(.callout).textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .padding(12)
        .task { loadMessages() }
    }

    private func loadMessages() {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(at: claudeDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
        for dir in projectDirs {
            let file = dir.appendingPathComponent("\(session.id).jsonl")
            if FileManager.default.fileExists(atPath: file.path) {
                messages = (try? reader.readFile(at: file)) ?? []
                return
            }
        }
    }
}
