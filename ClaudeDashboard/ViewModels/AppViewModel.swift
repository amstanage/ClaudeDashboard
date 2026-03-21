import SwiftUI

@Observable
final class AppViewModel {
    var currentModel: String = "Claude Opus 4.6"
    var effortLevel: String = "max"
    var sessionTokens: Int = 0
    var dailyTokens: Int = 0
    var sessionStartTime: Date? = nil
    private(set) var database: AnyObject? = nil

    var sessionDuration: String {
        guard let start = sessionStartTime else { return "—" }
        let elapsed = Date().timeIntervalSince(start)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
