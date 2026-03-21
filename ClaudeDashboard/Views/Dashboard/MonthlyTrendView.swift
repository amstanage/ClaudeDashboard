import SwiftUI
import Charts

struct MonthlyTrendView: View {
    let data: [DailyStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 30 Days").font(.headline)
            Chart(data) { stat in
                LineMark(x: .value("Date", stat.date), y: .value("Tokens", stat.totalTokens))
                    .foregroundStyle(Color.cyan).interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", stat.date), y: .value("Tokens", stat.totalTokens))
                    .foregroundStyle(LinearGradient(colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel { if let n = value.as(Int.self) { Text(WeeklyChartView.formatTokenCount(n)).font(.caption2) } }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(.quaternary)
                }
            }
            .frame(height: 150)
        }
        .glassCard()
    }
}
