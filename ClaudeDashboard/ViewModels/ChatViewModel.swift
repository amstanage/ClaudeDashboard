import SwiftUI

@MainActor @Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isWaitingForResponse: Bool = false
    var sessionInputTokens: Int = 0
    var sessionOutputTokens: Int = 0
    var sessionCacheTokens: Int = 0
    var messageCount: Int = 0
    var selectedModel: String = "opus"
    var selectedEffort: String = "max"
    var modelChanged: Bool = false
    var effortChanged: Bool = false
    var rawOutput: [String] = []
    var showTerminal: Bool = false
    var pendingAttachments: [FileAttachment] = []
    var attachmentError: String?

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

        let attachments = pendingAttachments
        let model = modelChanged ? selectedModel : nil
        let effort = effortChanged ? selectedEffort : nil

        messages.append(ChatMessage(role: .user, content: text, attachments: attachments))
        inputText = ""
        pendingAttachments = []
        attachmentError = nil
        isWaitingForResponse = true
        messageCount += 1
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }

        if !attachments.isEmpty {
            Task {
                let fileContents: [String] = await Task.detached {
                    attachments.compactMap { attachment in
                        guard let content = try? String(contentsOf: attachment.url, encoding: .utf8) else { return nil }
                        let lang = (attachment.fileName as NSString).pathExtension
                        return "```\(lang) (\(attachment.fileName))\n\(content)\n```"
                    }
                }.value

                let fullText = fileContents.isEmpty ? text : fileContents.joined(separator: "\n\n") + "\n\n" + text
                cliService.sendMessage(fullText, model: model, effort: effort)
            }
        } else {
            cliService.sendMessage(text, model: model, effort: effort)
        }
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
                sessionCacheTokens += (usage.cacheCreationInputTokens ?? 0) + (usage.cacheReadInputTokens ?? 0)
            }
            gotAssistantResponse = false
            isWaitingForResponse = false

        default: break
        }
    }

    func addAttachment(url: URL) {
        guard pendingAttachments.count < FileAttachment.maxFileCount else {
            attachmentError = "Maximum \(FileAttachment.maxFileCount) files per message"
            return
        }

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attrs[.size] as? Int64 else {
            attachmentError = "Cannot read file: \(url.lastPathComponent)"
            return
        }

        guard FileAttachment.isWithinSizeLimit(bytes: fileSize) else {
            attachmentError = "\(url.lastPathComponent) exceeds 1MB limit"
            return
        }

        let totalSize = pendingAttachments.reduce(Int64(0)) { $0 + $1.fileSize } + fileSize
        guard totalSize <= FileAttachment.maxTotalSize else {
            attachmentError = "Total attachment size exceeds 5MB limit"
            return
        }

        let fileName = url.lastPathComponent
        let fileType = FileAttachment.fileType(for: fileName)

        var thumbnailData: Data? = nil
        if fileType == .image, let image = NSImage(contentsOf: url) {
            let maxDim: CGFloat = 40
            let ratio = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
            let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
            let thumb = NSImage(size: newSize)
            thumb.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize))
            thumb.unlockFocus()
            if let tiffData = thumb.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiffData) {
                thumbnailData = rep.representation(using: .png, properties: [:])
            }
        }

        let attachment = FileAttachment(
            id: UUID(),
            url: url,
            fileName: fileName,
            fileType: fileType,
            fileSize: fileSize,
            thumbnailData: thumbnailData
        )
        pendingAttachments.append(attachment)
        attachmentError = nil
    }

    func removeAttachment(_ attachment: FileAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
        attachmentError = nil
    }

    func newConversation() {
        cliService.newSession()
        messages.removeAll()
        rawOutput.removeAll()
        sessionInputTokens = 0
        sessionOutputTokens = 0
        sessionCacheTokens = 0
        messageCount = 0
        sessionStartTime = nil
        isWaitingForResponse = false
        pendingAttachments = []
        attachmentError = nil
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
            totalCacheTokens: stats.totalCacheTokens,
            firstMessage: stats.firstMessage
        )
        try? db.insertSession(record)
        onSessionCreated?()
    }

    func toggleTerminal() { showTerminal.toggle() }
}
