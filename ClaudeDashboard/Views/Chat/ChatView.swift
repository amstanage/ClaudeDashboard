import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message).id(message.id)
                        }
                        if viewModel.isWaitingForResponse {
                            HStack {
                                ProgressView().controlSize(.small).padding(12)
                                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if viewModel.showTerminal {
                TerminalDrawerView(rawOutput: viewModel.rawOutput)
                    .frame(height: 200).transition(.move(edge: .bottom))
            }

            MessageInputView(viewModel: viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newConversation)) { _ in viewModel.newConversation() }
        .onReceive(NotificationCenter.default.publisher(for: .clearDisplay)) { _ in viewModel.clearDisplay() }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { withAnimation(.spring(duration: 0.3)) { viewModel.toggleTerminal() } } label: {
                    Image(systemName: "terminal")
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let newConversation = Notification.Name("newConversation")
    static let clearDisplay = Notification.Name("clearDisplay")
}
