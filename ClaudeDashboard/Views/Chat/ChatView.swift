import SwiftUI

struct ChatView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            chatScrollArea
            terminalSection
            inputSection
        }
        .modifier(ChatStatsSync(viewModel: viewModel, appViewModel: appViewModel))
        .onReceive(NotificationCenter.default.publisher(for: .newConversation)) { _ in viewModel.newConversation() }
        .onReceive(NotificationCenter.default.publisher(for: .clearDisplay)) { _ in viewModel.clearDisplay() }
    }

    private var chatScrollArea: some View {
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
    }

    @ViewBuilder
    private var terminalSection: some View {
        if viewModel.showTerminal {
            TerminalDrawerView(rawOutput: viewModel.rawOutput)
                .frame(height: 200).transition(.move(edge: .bottom))
        }
    }

    private var inputSection: some View {
        HStack(alignment: .bottom, spacing: 8) {
            MessageInputView(viewModel: viewModel)

            Button {
                withAnimation(.spring(duration: 0.3)) { viewModel.toggleTerminal() }
            } label: {
                Image(systemName: viewModel.showTerminal ? "terminal.fill" : "terminal")
                    .font(.title3)
                    .foregroundStyle(viewModel.showTerminal ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("t", modifiers: .command)
            .help("Toggle Terminal (Cmd+T)")
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }
}

/// Separate modifier to sync chat stats to the app view model without overloading the body type-checker
struct ChatStatsSync: ViewModifier {
    @Bindable var viewModel: ChatViewModel
    var appViewModel: AppViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.sessionInputTokens) { _, _ in
                appViewModel.sessionInputTokens = viewModel.sessionInputTokens
                appViewModel.sessionOutputTokens = viewModel.sessionOutputTokens
            }
            .onChange(of: viewModel.sessionOutputTokens) { _, _ in
                appViewModel.sessionInputTokens = viewModel.sessionInputTokens
                appViewModel.sessionOutputTokens = viewModel.sessionOutputTokens
            }
            .onChange(of: viewModel.messageCount) { _, newValue in
                appViewModel.messageCount = newValue
                if let lastAssistant = viewModel.messages.last(where: { $0.role == .assistant }),
                   let model = lastAssistant.model {
                    appViewModel.currentModel = model.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-", with: " ").capitalized
                }
            }
            .onChange(of: viewModel.selectedModel) { _, newValue in
                appViewModel.currentModel = newValue.replacingOccurrences(of: "claude-", with: "").replacingOccurrences(of: "-", with: " ").capitalized
            }
            .onChange(of: viewModel.selectedEffort) { _, newValue in
                appViewModel.effortLevel = newValue
            }
            .onChange(of: viewModel.sessionStartTime) { _, newValue in
                appViewModel.sessionStartTime = newValue
            }
    }
}

extension Notification.Name {
    static let newConversation = Notification.Name("newConversation")
    static let clearDisplay = Notification.Name("clearDisplay")
}
