import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    }
}

extension View {
    func glassCard() -> some View {
        self
            .padding(16)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    }
}
