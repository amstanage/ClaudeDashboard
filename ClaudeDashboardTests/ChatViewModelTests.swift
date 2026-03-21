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
        let event = CLIEvent(type: "assistant", message: CLIEvent.CLIMessage(
            role: "assistant",
            content: [CLIEvent.ContentBlock(type: "text", text: "Hi there!")],
            usage: CLIEvent.TokenUsage(inputTokens: 10, outputTokens: 5, cacheCreationInputTokens: nil, cacheReadInputTokens: nil),
            model: "claude-opus-4-6"
        ))
        vm.handleCLIEvent(event)
        XCTAssertEqual(vm.messages.count, 1)
        XCTAssertEqual(vm.messages[0].role, .assistant)
        XCTAssertEqual(vm.messages[0].content, "Hi there!")
        XCTAssertEqual(vm.sessionTokens, 15)
    }

    @MainActor func testNewConversationClearsMessages() {
        let vm = ChatViewModel()
        vm.inputText = "Hello"
        vm.sendMessage()
        vm.handleCLIEvent(CLIEvent(type: "assistant", message: CLIEvent.CLIMessage(
            role: "assistant",
            content: [CLIEvent.ContentBlock(type: "text", text: "Hi")],
            usage: CLIEvent.TokenUsage(inputTokens: 5, outputTokens: 3, cacheCreationInputTokens: nil, cacheReadInputTokens: nil),
            model: "claude-opus-4-6"
        )))
        XCTAssertEqual(vm.messages.count, 2)
        vm.newConversation()
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertEqual(vm.sessionTokens, 0)
    }
}
