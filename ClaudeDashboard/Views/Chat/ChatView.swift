import SwiftUI
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Bindable var viewModel: ChatViewModel
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            chatScrollArea
            terminalSection
            inputSection
        }
        .overlay {
            // Drop zone overlay using AppKit for reliable drag-and-drop
            DropZoneView(isTargeted: $isDropTargeted) { urls in
                for url in urls {
                    viewModel.addAttachment(url: url)
                }
            }
            .allowsHitTesting(isDropTargeted ? false : true)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .allowsHitTesting(false)
            }
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

// MARK: - AppKit Drop Zone (reliable drag-and-drop)

/// NSViewRepresentable that uses AppKit's NSDraggingDestination for reliable file drops.
/// SwiftUI's .onDrop and .dropDestination are unreliable with ScrollView and glassEffect.
struct DropZoneView: NSViewRepresentable {
    @Binding var isTargeted: Bool
    var onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> DropReceivingView {
        let view = DropReceivingView()
        view.onDrop = onDrop
        view.onTargetChanged = { targeted in
            DispatchQueue.main.async {
                isTargeted = targeted
            }
        }
        view.registerForDraggedTypes([.fileURL, .png, .tiff, .URL])
        return view
    }

    func updateNSView(_ nsView: DropReceivingView, context: Context) {
        nsView.onDrop = onDrop
        nsView.onTargetChanged = { targeted in
            DispatchQueue.main.async {
                isTargeted = targeted
            }
        }
    }
}

/// AppKit view that accepts file drops via NSDraggingDestination
final class DropReceivingView: NSView {
    var onDrop: (([URL]) -> Void)?
    var onTargetChanged: ((Bool) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onTargetChanged?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetChanged?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onTargetChanged?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetChanged?(false)

        let pasteboard = sender.draggingPasteboard

        // Try to get file URLs directly
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            onDrop?(urls)
            return true
        }

        // Fall back: if image data was dropped (e.g. from Photos), save to temp file
        if let image = NSImage(pasteboard: pasteboard) {
            if let tiffData = image.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiffData),
               let pngData = rep.representation(using: .png, properties: [:]) {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".png")
                do {
                    try pngData.write(to: tempURL)
                    onDrop?([tempURL])
                    return true
                } catch {
                    return false
                }
            }
        }

        return false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Return nil for normal mouse events so clicks pass through to the ScrollView.
        // Drag operations use the dragging protocol methods, not hitTest.
        return nil
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
                appViewModel.sessionCacheTokens = viewModel.sessionCacheTokens
            }
            .onChange(of: viewModel.sessionOutputTokens) { _, _ in
                appViewModel.sessionInputTokens = viewModel.sessionInputTokens
                appViewModel.sessionOutputTokens = viewModel.sessionOutputTokens
                appViewModel.sessionCacheTokens = viewModel.sessionCacheTokens
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
