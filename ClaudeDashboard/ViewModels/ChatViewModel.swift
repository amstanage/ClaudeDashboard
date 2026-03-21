import SwiftUI

@MainActor @Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isWaitingForResponse: Bool = false
    var sessionTokens: Int = 0
    var selectedModel: String = "claude-opus-4-6"
    var selectedEffort: String = "max"
    var rawOutput: [String] = []
    var showTerminal: Bool = false

    private let cliService = CLIService()
    private var sessionStartTime: Date?

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
            if status != 0 {
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
        if sessionStartTime == nil {
            sessionStartTime = Date()
            if !cliService.isRunning { try? cliService.startSession() }
        }
        cliService.send(message: text)
    }

    func handleCLIEvent(_ event: CLIEvent) {
        switch event.type {
        case "assistant":
            if let text = event.textContent {
                messages.append(ChatMessage(role: .assistant, content: text, model: event.message?.model, tokensIn: event.message?.usage?.inputTokens, tokensOut: event.message?.usage?.outputTokens, isComplete: true))
            }
            if let usage = event.message?.usage { sessionTokens += usage.totalTokens }
            if let model = event.message?.model { selectedModel = model }
            isWaitingForResponse = false
        case "progress": break
        default: break
        }
    }

    func newConversation() {
        cliService.stop()
        messages.removeAll()
        rawOutput.removeAll()
        sessionTokens = 0
        sessionStartTime = nil
        isWaitingForResponse = false
    }

    func clearDisplay() {
        messages.removeAll()
        rawOutput.removeAll()
    }

    func toggleTerminal() { showTerminal.toggle() }
}
