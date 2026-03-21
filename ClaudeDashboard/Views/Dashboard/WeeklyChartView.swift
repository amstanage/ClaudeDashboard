import SwiftUI
import Charts

struct WeeklyChartView: View {
    let data: [DailyStats]
    private let dayFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE"; return f }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week").font(.headline)
            Chart(data) { stat in
                BarMark(x: .value("Day", dayFormatter.string(from: stat.date)), y: .value("Tokens", stat.totalTokens))
                    .foregroundStyle(Gradient(colors: [Color.cyan.opacity(0.6), Color.cyan]))
                    .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel { if let n = value.as(Int.self) { Text(Self.formatTokenCount(n)).font(.caption2) } }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.quaternary)
                }
            }
            .frame(height: 150)
        }
        .glassCard()
    }

    static func formatTokenCount(_ n: Int) -> String {
        if n >= 1_000_000 { return "\(n / 1_000_000)M" }
        if n >= 1_000 { return "\(n / 1_000)K" }
        return "\(n)"
    }
}
