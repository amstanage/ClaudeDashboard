import SwiftUI

struct StatsBarView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        HStack(spacing: 16) {
            StatChip(label: "Model", value: appViewModel.currentModel)
            StatChip(label: "Effort", value: appViewModel.effortLevel)
            StatChip(label: "Session", value: "\(appViewModel.sessionTokens) tokens")
            StatChip(label: "Today", value: "\(appViewModel.dailyTokens) tokens")
            StatChip(label: "Duration", value: appViewModel.sessionDuration)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 0))
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
