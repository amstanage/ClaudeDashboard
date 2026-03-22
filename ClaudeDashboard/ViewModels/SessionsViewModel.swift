import SwiftUI

@MainActor @Observable
final class SessionsViewModel {
    private(set) var filteredSessions: [SessionRecord] = []
    private(set) var availableModels: [String] = []
    var searchQuery: String = ""
    var expandedSessionId: String? = nil

    var selectedModelFilter: String? = nil {
        didSet { updateFiltered() }
    }

    private var sessions: [SessionRecord] = [] {
        didSet {
            availableModels = Array(Set(sessions.compactMap(\.model))).sorted()
            updateFiltered()
        }
    }

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

    private func updateFiltered() {
        if let filter = selectedModelFilter {
            filteredSessions = sessions.filter { $0.model == filter }
        } else {
            filteredSessions = sessions
        }
    }
}
