import SwiftUI

@MainActor @Observable
final class SessionsViewModel {
    var sessions: [SessionRecord] = []
    var searchQuery: String = ""
    var selectedModelFilter: String? = nil
    var expandedSessionId: String? = nil

    private var db: DatabaseService?

    func configure(database: DatabaseService) { self.db = database }

    func loadSessions() async {
        guard let db else { return }
        sessions = (try? db.fetchSessions(limit: 200)) ?? []
    }

    func search() async {
        guard let db else { return }
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        if query.isEmpty { await loadSessions() } else { sessions = (try? db.searchSessions(query: query)) ?? [] }
    }

    var filteredSessions: [SessionRecord] {
        guard let filter = selectedModelFilter else { return sessions }
        return sessions.filter { $0.model == filter }
    }

    var availableModels: [String] {
        Array(Set(sessions.compactMap(\.model))).sorted()
    }
}
