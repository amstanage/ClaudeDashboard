import XCTest
@testable import Claude_Dashboard

final class ChatViewModelTests: XCTestCase {
    @MainActor func testSendMessageAddsUserMessage() {
        let vm = ChatViewModel()
        vm.inputText = "Hello Claude"
        vm.sendMessage()
        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages[0].role, .user)
        XCTAssertEqual(vm.messages[0].content, "Hello Claude")
        XCTAssertTrue(vm.inputText.isEmpty)
    }

    @MainActor func testSendEmptyMessageDoesNothing() {
        let vm = ChatViewModel()
        vm.inputText = "   "
        vm.sendMessage()
        XCTAssertTrue(vm.messages.isEmpty)
    }

    @MainActor func testHandleAssistantEvent() {
        let vm = ChatViewModel()
        let assistantEvent = CLIEvent(type: "assistant", message: CLIEvent.CLIMessage(
            role: "assistant",
            content: [CLIEvent.ContentBlock(type: "text", text: "Hi there!")],
            usage: nil,
            model: "claude-opus-4-6"
        ), result: nil, subtype: nil, sessionId: nil, usage: nil)
        vm.handleCLIEvent(assistantEvent)
        // Token counts come from the result event, not the assistant event
        let resultEvent = CLIEvent(type: "result", message: nil,
            result: "Hi there!", subtype: "success", sessionId: nil,
            usage: CLIEvent.TokenUsage(inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: nil, cacheReadInputTokens: nil))
        vm.handleCLIEvent(resultEvent)
        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages[0].role, .assistant)
        XCTAssertEqual(vm.messages[0].content, "Hi there!")
        XCTAssertEqual(vm.messages[0].tokensOut, 5)
        XCTAssertEqual(vm.messages[0].tokensIn, 10)
        XCTAssertEqual(vm.sessionInputTokens, 10)
        XCTAssertEqual(vm.sessionOutputTokens, 5)
    }

    @MainActor func testNewConversationClearsMessages() {
        let vm = ChatViewModel()
        vm.inputText = "Hello"
        vm.sendMessage()
        vm.handleCLIEvent(CLIEvent(type: "assistant", message: CLIEvent.CLIMessage(
            role: "assistant",
            content: [CLIEvent.ContentBlock(type: "text", text: "Hi")],
            usage: nil,
            model: "claude-opus-4-6"
        ), result: nil, subtype: nil, sessionId: nil, usage: nil))
        vm.handleCLIEvent(CLIEvent(type: "result", message: nil,
            result: "Hi", subtype: "success", sessionId: nil,
            usage: CLIEvent.TokenUsage(inputTokens: 5, outputTokens: 3, cacheCreationInputTokens: nil, cacheReadInputTokens: nil)))
        XCTAssertEqual(vm.messages.count, 2)
        vm.newConversation()
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertEqual(vm.sessionInputTokens, 0)
        XCTAssertEqual(vm.sessionOutputTokens, 0)
    }
}
