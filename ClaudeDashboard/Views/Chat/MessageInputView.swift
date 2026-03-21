import SwiftUI

struct MessageInputView: View {
    @Bindable var viewModel: ChatViewModel

    private let models = ["opus", "sonnet", "haiku"]
    private let efforts = ["low", "medium", "high", "max"]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Menu {
                ForEach(models, id: \.self) { model in
                    Button {
                        viewModel.selectedModel = model
                        viewModel.modelChanged = true
                    } label: {
                        HStack {
                            Text(model.capitalized)
                            if viewModel.selectedModel == model {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "cpu").font(.caption)
                    Text(viewModel.selectedModel.capitalized).font(.caption2)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                ForEach(efforts, id: \.self) { effort in
                    Button {
                        viewModel.selectedEffort = effort
                        viewModel.effortChanged = true
                    } label: {
                        HStack {
                            Text(effort.capitalized)
                            if viewModel.selectedEffort == effort {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "gauge.medium").font(.caption)
                    Text(viewModel.selectedEffort.capitalized).font(.caption2)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

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
        .padding(.leading, 16).padding(.bottom, 12)
    }
}
