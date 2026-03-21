import SwiftUI

enum AppTab: Hashable {
    case chat
    case dashboard
    case sessions
    case skills
    case chatHistory(String) // session ID

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .dashboard: return "chart.bar"
        case .sessions: return "clock.arrow.circlepath"
        case .skills: return "puzzlepiece.extension"
        case .chatHistory: return "text.bubble"
        }
    }
}

struct ContentView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedTab: AppTab = .chat
    @State private var chatViewModel = ChatViewModel()
    @State private var chatHistory: [SessionRecord] = []

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedTab: $selectedTab,
                chatHistory: chatHistory,
                onNewChat: { newChat() },
                onDeleteChat: { deleteChat($0) },
                onClearHistory: { clearHistory() }
            )
        } detail: {
            detailContent
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                StatsBarView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(.ultraThinMaterial)
        .focusedSceneValue(\.selectedTab, $selectedTab)
        .onChange(of: appViewModel.database != nil) { _, ready in
            if ready { loadChatHistory() }
        }
        .onChange(of: selectedTab) { _, _ in loadChatHistory() }
        .onReceive(NotificationCenter.default.publisher(for: .newConversation)) { _ in newChat() }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .chat:
            ChatView(viewModel: chatViewModel)
        case .dashboard:
            DashboardView()
        case .sessions:
            SessionsView()
        case .skills:
            SkillsView()
        case .chatHistory(let sessionId):
            SessionDetailFullView(sessionId: sessionId)
        }
    }

    private func newChat() {
        chatViewModel.newConversation()
        selectedTab = .chat
        // Reload history after a delay to pick up the completed session
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { loadChatHistory() }
    }

    private func deleteChat(_ sessionId: String) {
        guard let db = appViewModel.database else { return }
        try? db.deleteSession(id: sessionId)
        chatHistory.removeAll { $0.id == sessionId }
        if case .chatHistory(let id) = selectedTab, id == sessionId {
            selectedTab = .chat
        }
    }

    private func clearHistory() {
        guard let db = appViewModel.database else { return }
        try? db.deleteAllSessions()
        chatHistory.removeAll()
        selectedTab = .chat
    }

    private func loadChatHistory() {
        guard let db = appViewModel.database else { return }
        chatHistory = (try? db.fetchSessions(limit: 50)) ?? []
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @Binding var selectedTab: AppTab
    let chatHistory: [SessionRecord]
    let onNewChat: () -> Void
    let onDeleteChat: (String) -> Void
    let onClearHistory: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        List(selection: $selectedTab) {
            Section {
                Label("New Chat", systemImage: "plus.bubble")
                    .tag(AppTab.chat)
            }

            Section("Analytics") {
                Label("Dashboard", systemImage: AppTab.dashboard.icon)
                    .tag(AppTab.dashboard)
                Label("Sessions", systemImage: AppTab.sessions.icon)
                    .tag(AppTab.sessions)
            }

            Section("Configuration") {
                Label("Skills", systemImage: AppTab.skills.icon)
                    .tag(AppTab.skills)
            }

            Section("Chat History") {
                ForEach(chatHistory) { session in
                    chatRow(session)
                        .tag(AppTab.chatHistory(session.id))
                        .contextMenu {
                            Button(role: .destructive) {
                                onDeleteChat(session.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }

                if !chatHistory.isEmpty {
                    Button(role: .destructive) {
                        onClearHistory()
                    } label: {
                        Label("Clear History", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                if chatHistory.isEmpty {
                    Text("No conversations yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .toolbar {
            ToolbarItem {
                Button { onNewChat() } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Chat")
            }
        }
    }

    private func chatRow(_ session: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.firstMessage ?? "Untitled")
                .lineLimit(1)
                .font(.callout)
            HStack(spacing: 4) {
                if let model = session.model {
                    Text(model.replacingOccurrences(of: "claude-", with: "").capitalized)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(Self.dateFormatter.string(from: session.startedAt))
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
        }
    }
}

// MARK: - Full session detail view (for viewing history)

struct SessionDetailFullView: View {
    let sessionId: String
    @State private var messages: [CLIEvent] = []
    @State private var sessionInfo: String = ""
    private let reader = JSONLReader()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if messages.isEmpty {
                    Text("Loading conversation...")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, event in
                        if let text = event.textContent, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            let isUser = event.type == "user"
                            HStack {
                                if isUser { Spacer(minLength: 80) }
                                VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                                    Text(LocalizedStringKey(cleanText))
                                        .textSelection(.enabled)
                                        .padding(12)
                                        .background(isUser ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))

                                    if let tokens = event.message?.usage {
                                        Text("\(tokens.totalTokens) tokens")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                if !isUser { Spacer(minLength: 80) }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .onAppear { loadMessages() }
    }

    private func loadMessages() {
        let claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        guard let projectDirs = try? FileManager.default.contentsOfDirectory(at: claudeDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
        for dir in projectDirs {
            let file = dir.appendingPathComponent("\(sessionId).jsonl")
            if FileManager.default.fileExists(atPath: file.path) {
                messages = (try? reader.readFile(at: file)) ?? []
                return
            }
            // Also check subagents directory
            let subagentsDir = dir.appendingPathComponent("subagents")
            let subFile = subagentsDir.appendingPathComponent("\(sessionId).jsonl")
            if FileManager.default.fileExists(atPath: subFile.path) {
                messages = (try? reader.readFile(at: subFile)) ?? []
                return
            }
        }
    }
}

// MARK: - Commands

struct AppCommands: Commands {
    @FocusedBinding(\.selectedTab) var selectedTab

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Conversation") {
                NotificationCenter.default.post(name: .newConversation, object: nil)
            }.keyboardShortcut("n", modifiers: .command)
            Button("Clear Display") {
                NotificationCenter.default.post(name: .clearDisplay, object: nil)
            }.keyboardShortcut("k", modifiers: .command)
            Divider()
            Button("Chat") { selectedTab = .chat }.keyboardShortcut("1", modifiers: .command)
            Button("Dashboard") { selectedTab = .dashboard }.keyboardShortcut("2", modifiers: .command)
            Button("Sessions") { selectedTab = .sessions }.keyboardShortcut("3", modifiers: .command)
            Button("Skills") { selectedTab = .skills }.keyboardShortcut("4", modifiers: .command)
        }
    }
}

struct SelectedTabKey: FocusedValueKey {
    typealias Value = Binding<AppTab>
}

extension FocusedValues {
    var selectedTab: Binding<AppTab>? {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}
