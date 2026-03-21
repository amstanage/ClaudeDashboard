import Foundation

struct DailyStats: Identifiable {
    let date: Date
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let sessionCount: Int

    var id: Date { date }
    var totalTokens: Int { totalInputTokens + totalOutputTokens }

    func intensity(max: Int) -> Double {
        guard max > 0 else { return 0 }
        return min(Double(totalTokens) / Double(max), 1.0)
    }
}
