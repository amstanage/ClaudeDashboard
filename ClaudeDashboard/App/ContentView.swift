import SwiftUI

enum AppTab: String, CaseIterable {
    case chat = "Chat"
    case dashboard = "Dashboard"
    case sessions = "Sessions"

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .dashboard: return "chart.bar"
        case .sessions: return "clock.arrow.circlepath"
        }
    }
}

struct ContentView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedTab: AppTab = .chat

    var body: some View {
        VStack(spacing: 0) {
            StatsBarView()
            Group {
                switch selectedTab {
                case .chat: ChatView()
                case .dashboard: DashboardView()
                case .sessions: SessionsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $selectedTab) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
        }
        .background(.ultraThinMaterial)
    }
}
