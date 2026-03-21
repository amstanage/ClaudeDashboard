import SwiftUI

struct StatsBarView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 20) {
            StatChip(label: "Model", value: appViewModel.currentModel)
            StatChip(label: "Effort", value: appViewModel.effortLevel)

            Divider().frame(height: 24)

            StatChip(label: "Sent", value: formatTokens(appViewModel.sessionInputTokens))
            StatChip(label: "Received", value: formatTokens(appViewModel.sessionOutputTokens))
            StatChip(label: "Messages", value: "\(appViewModel.messageCount)")

            Divider().frame(height: 24)

            StatChip(label: "Today", value: formatTokens(appViewModel.dailyTokens))
            StatChip(label: "Duration", value: sessionDuration)
        }
        .padding(.horizontal, 24)
        .onReceive(timer) { now = $0 }
    }

    private var sessionDuration: String {
        guard let start = appViewModel.sessionStartTime else { return "—" }
        let elapsed = now.timeIntervalSince(start)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            return String(format: "%d:%02d:%02d", hours, minutes % 60, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatTokens(_ count: Int) -> String {
        if count == 0 { return "0" }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

struct StatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}
