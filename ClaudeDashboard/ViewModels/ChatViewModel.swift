import SwiftUI

@MainActor @Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isWaitingForResponse: Bool = false
    var sessionInputTokens: Int = 0
    var sessionOutputTokens: Int = 0
    var messageCount: Int = 0
    var selectedModel: String = "opus"
    var selectedEffort: String = "max"
    var modelChanged: Bool = false
    var effortChanged: Bool = false
    var rawOutput: [String] = []
    var showTerminal: Bool = false

    private let cliService = CLIService()
    var sessionStartTime: Date?
    var onSessionCreated: (() -> Void)?

    private let reader = JSONLReader()
    private weak var database: DatabaseService?

    func configure(database: DatabaseService?) {
        self.database = database
    }

    init() {
        cliService.onEvent = { [weak self] event in
            self?.handleCLIEvent(event)
        }
        cliService.onRawOutput = { [weak self] output in
            self?.rawOutput.append(output)
        }
        cliService.onError = { [weak self] error in
            self?.rawOutput.append("[stderr] \(error)")
        }
        cliService.onProcessExit = { [weak self] status in
            self?.isWaitingForResponse = false
            // 0 = normal exit, 143 = SIGTERM (we killed it), 137 = SIGKILL (we killed it)
            if status != 0 && status != 143 && status != 137 {
                self?.messages.append(ChatMessage(role: .assistant, content: "CLI process exited with status \(status)", isComplete: true))
            }
            self?.refreshTokensFromSessionFile()
        }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(role: .user, content: text))
        inputText = ""
        isWaitingForResponse = true
        messageCount += 1
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }
        cliService.sendMessage(
            text,
            model: modelChanged ? selectedModel : nil,
            effort: effortChanged ? selectedEffort : nil
        )
    }

    private var gotAssistantResponse = false

    func handleCLIEvent(_ event: CLIEvent) {
        switch event.type {
        case "assistant":
            if let text = event.textContent, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                messages.append(ChatMessage(role: .assistant, content: cleanText, model: event.message?.model, isComplete: true))
                gotAssistantResponse = true
                messageCount += 1
            }
            if let model = event.message?.model { selectedModel = model }
            isWaitingForResponse = false

        case "result":
            if !gotAssistantResponse, let text = event.result, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                messages.append(ChatMessage(role: .assistant, content: cleanText, isComplete: true))
                messageCount += 1
            }
            // Update the last assistant message with final accurate token counts from the result event
            if let usage = event.usage, let lastIndex = messages.indices.last, messages[lastIndex].role == .assistant {
                messages[lastIndex].tokensIn = usage.inputTokens
                messages[lastIndex].tokensOut = usage.outputTokens
            }
            // Accumulate session totals from result event (has final accurate counts)
            if let usage = event.usage {
                sessionInputTokens += usage.inputTokens
                sessionOutputTokens += usage.outputTokens
            }
            gotAssistantResponse = false
            isWaitingForResponse = false

        default: break
        }
    }

    func newConversation() {
        cliService.newSession()
        messages.removeAll()
        rawOutput.removeAll()
        sessionInputTokens = 0
        sessionOutputTokens = 0
        messageCount = 0
        sessionStartTime = nil
        isWaitingForResponse = false
    }

    func clearDisplay() {
        messages.removeAll()
        rawOutput.removeAll()
    }

    private func refreshTokensFromSessionFile() {
        guard let sessionId = cliService.currentSessionId else { return }
        let reader = self.reader
        let startTime = self.sessionStartTime
        Task.detached {
            let claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
            guard let projectDirs = try? FileManager.default.contentsOfDirectory(at: claudeDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
            for dir in projectDirs {
                let file = dir.appendingPathComponent("\(sessionId).jsonl")
                if FileManager.default.fileExists(atPath: file.path) {
                    let events = (try? reader.readFile(at: file)) ?? []
                    let stats = reader.extractSessionStats(from: events)
                    let projectPath = dir.lastPathComponent.replacingOccurrences(of: "-", with: "/")
                    await MainActor.run { [stats] in
                        self.sessionInputTokens = stats.totalInputTokens
                        self.sessionOutputTokens = stats.totalOutputTokens
                        self.saveSessionToDatabase(sessionId: sessionId, projectPath: projectPath, stats: stats, startTime: startTime)
                    }
                    return
                }
            }
        }
    }

    private func saveSessionToDatabase(sessionId: String, projectPath: String, stats: SessionStats, startTime: Date?) {
        guard let db = database else {
            onSessionCreated?()
            return
        }
        let record = SessionRecord(
            id: sessionId,
            projectPath: projectPath,
            startedAt: startTime ?? Date(),
            endedAt: Date(),
            model: stats.model,
            totalInputTokens: stats.totalInputTokens,
            totalOutputTokens: stats.totalOutputTokens,
            firstMessage: stats.firstMessage
        )
        try? db.insertSession(record)
        onSessionCreated?()
    }

    func toggleTerminal() { showTerminal.toggle() }
}
