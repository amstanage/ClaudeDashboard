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
                messages.append(ChatMessage(role: .assistant, content: cleanText, model: event.message?.model, tokensIn: event.message?.usage?.inputTokens, tokensOut: event.message?.usage?.outputTokens, isComplete: true))
                gotAssistantResponse = true
                messageCount += 1
            }
            if let usage = event.message?.usage {
                sessionInputTokens += usage.inputTokens
                sessionOutputTokens += usage.outputTokens
            }
            if let model = event.message?.model { selectedModel = model }
            isWaitingForResponse = false

        case "result":
            if !gotAssistantResponse, let text = event.result, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                messages.append(ChatMessage(role: .assistant, content: cleanText, isComplete: true))
                messageCount += 1
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

    func toggleTerminal() { showTerminal.toggle() }
}
