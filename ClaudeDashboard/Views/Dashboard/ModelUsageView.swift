import SwiftUI
import Charts

struct ModelUsageView: View {
    let data: [ModelUsageEntry]
    @Binding var period: Int

    private var totalTokens: Int { data.reduce(0) { $0 + $1.totalTokens } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Models").font(.headline)
                Spacer()
                Picker("Period", selection: $period) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 160)
            }
            if data.isEmpty {
                Text("No usage data").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
            } else {
                Chart(data) { entry in
                    SectorMark(angle: .value("Tokens", entry.totalTokens), innerRadius: .ratio(0.6), angularInset: 2)
                        .foregroundStyle(entry.color).cornerRadius(4)
                }
                .frame(height: 150)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(data) { entry in
                        HStack(spacing: 8) {
                            Circle().fill(entry.color).frame(width: 8, height: 8)
                            Text(entry.displayName).font(.caption)
                            Spacer()
                            Text(WeeklyChartView.formatTokenCount(entry.totalTokens)).font(.caption).foregroundStyle(.secondary)
                            if totalTokens > 0 {
                                Text("(\(Int(Double(entry.totalTokens) / Double(totalTokens) * 100))%)").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
        .glassCard()
    }
}
