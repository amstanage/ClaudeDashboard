import SwiftUI

struct UsageHeatmapView: View {
    let data: [DailyStats]
    let maxTokens: Int
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let rows = 7
    private let cols = 52
    private let dayLabels = ["Mon", "", "Wed", "", "Fri", "", "Sun"]
    @State private var hoveredIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage Activity").font(.headline)
            HStack(alignment: .top, spacing: 2) {
                VStack(spacing: cellSpacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        Text(dayLabels[row]).font(.caption2).foregroundStyle(.secondary)
                            .frame(width: 28, height: cellSize, alignment: .trailing)
                    }
                }
                HStack(spacing: cellSpacing) {
                    ForEach(0..<cols, id: \.self) { col in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<rows, id: \.self) { row in
                                let index = col * rows + row
                                if index < data.count {
                                    let stats = data[index]
                                    let intensity = stats.intensity(max: maxTokens)
                                    HeatmapCell(
                                        intensity: intensity,
                                        cellSize: cellSize,
                                        isHovered: hoveredIndex == index,
                                        stats: stats
                                    )
                                    .onHover { hovering in
                                        hoveredIndex = hovering ? index : nil
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.black)
                                        .frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                }
            }
            HStack(spacing: 4) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 2).fill(Self.colorForIntensity(intensity))
                        .frame(width: cellSize, height: cellSize)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .glassCard()
    }

    static func colorForIntensity(_ intensity: Double) -> Color {
        if intensity <= 0 { return .black }
        return Color(red: 0, green: 0.5 + (intensity * 0.5), blue: 0.5 + (intensity * 0.5)).opacity(0.3 + intensity * 0.7)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()
}

private struct HeatmapCell: View {
    let intensity: Double
    let cellSize: CGFloat
    let isHovered: Bool
    let stats: DailyStats

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(UsageHeatmapView.colorForIntensity(intensity))
            .frame(width: cellSize, height: cellSize)
            .scaleEffect(isHovered ? 1.8 : 1.0)
            .zIndex(isHovered ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .popover(isPresented: .constant(isHovered), arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Self.tooltipDateFormatter.string(from: stats.date))
                        .font(.caption.bold())
                        .foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(UsageHeatmapView.colorForIntensity(intensity))
                            .frame(width: 8, height: 8)
                        Text(Self.formatTokens(stats.totalTokens))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            }
    }

    private static let tooltipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d, yyyy"
        return f
    }()

    private static func formatTokens(_ count: Int) -> String {
        if count == 0 { return "No tokens" }
        if count < 1_000 { return "\(count) tokens" }
        if count < 1_000_000 {
            let k = Double(count) / 1_000
            return String(format: "%.1fK tokens", k)
        }
        let m = Double(count) / 1_000_000
        return String(format: "%.1fM tokens", m)
    }
}
