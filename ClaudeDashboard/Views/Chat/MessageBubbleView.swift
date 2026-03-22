import SwiftUI

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 80) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    if !message.attachments.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(message.attachments) { attachment in
                                    AttachmentChipView(attachment: attachment)
                                }
                            }
                        }
                    }
                    MessageContentView(content: message.content)
                }
                .padding(12)
                .if(message.role == .user) { view in
                    view.glassEffect(.regular.tint(.accentColor.opacity(0.3)).interactive(), in: .rect(cornerRadii: .init(topLeading: 16, bottomLeading: 16, bottomTrailing: 4, topTrailing: 16)))
                }
                .if(message.role == .assistant) { view in
                    view.glassEffect(.regular.interactive(), in: .rect(cornerRadii: .init(topLeading: 16, bottomLeading: 4, bottomTrailing: 16, topTrailing: 16)))
                }
                if let out = message.tokensOut, out > 0 {
                    Text("\(out) tokens").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            if message.role == .assistant { Spacer(minLength: 80) }
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition { transform(self) } else { self }
    }
}
