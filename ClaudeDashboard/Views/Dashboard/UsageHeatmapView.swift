import SwiftUI

struct UsageHeatmapView: View {
    let data: [DailyStats]
    let maxTokens: Int
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let rows = 7
    private let cols = 52
    private let dayLabels = ["Mon", "", "Wed", "", "Fri", "", "Sun"]

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
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Self.colorForIntensity(intensity))
                                        .frame(width: cellSize, height: cellSize)
                                        .help("\(Self.dateFormatter.string(from: stats.date)): \(stats.totalTokens) tokens")
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
