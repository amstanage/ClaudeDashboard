import SwiftUI

struct MessageInputView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Menu {
                ForEach(["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5"], id: \.self) { model in
                    Button(model.replacingOccurrences(of: "claude-", with: "").capitalized) { viewModel.selectedModel = model }
                }
            } label: { Image(systemName: "cpu").font(.caption) }
            .menuStyle(.borderlessButton).frame(width: 30)

            Menu {
                ForEach(["low", "medium", "high", "max"], id: \.self) { effort in
                    Button(effort.capitalized) { viewModel.selectedEffort = effort }
                }
            } label: { Image(systemName: "gauge.medium").font(.caption) }
            .menuStyle(.borderlessButton).frame(width: 30)

            TextField("Message Claude...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...10)
                .onSubmit {
                    if !NSEvent.modifierFlags.contains(.shift) { viewModel.sendMessage() }
                }

            Button { viewModel.sendMessage() } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title2)
                    .foregroundStyle(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.accentColor))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isWaitingForResponse)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        .padding(.horizontal, 16).padding(.bottom, 12)
    }
}
