import Foundation

struct SessionRecord: Identifiable {
    let id: String
    let projectPath: String
    let startedAt: Date
    let endedAt: Date?
    let model: String?
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let firstMessage: String?

    var totalTokens: Int { totalInputTokens + totalOutputTokens }

    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    var durationFormatted: String {
        guard let dur = duration else { return "—" }
        let minutes = Int(dur) / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let remainMinutes = minutes % 60
        return "\(hours)h \(remainMinutes)m"
    }
}
