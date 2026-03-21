import SwiftUI

struct TerminalDrawerView: View {
    let rawOutput: [String]
    @State private var dragHeight: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
                .overlay(alignment: .center) {
                    Capsule().fill(.tertiary).frame(width: 40, height: 4).padding(.vertical, 4)
                }
                .gesture(DragGesture().onChanged { value in
                    dragHeight = max(100, min(500, dragHeight - value.translation.height))
                })
                .onContinuousHover { phase in
                    switch phase {
                    case .active: NSCursor.resizeUpDown.push()
                    case .ended: NSCursor.pop()
                    }
                }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rawOutput.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.green.opacity(0.9))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: rawOutput.count) { _, _ in
                    if let last = rawOutput.indices.last { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
            .background(Color.black.opacity(0.85))
        }
        .frame(height: dragHeight)
    }
}
