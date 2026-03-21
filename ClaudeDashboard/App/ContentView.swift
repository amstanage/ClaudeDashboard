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
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $selectedTab) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }.pickerStyle(.segmented).frame(width: 300)
            }
        }
        .background(.ultraThinMaterial)
        .focusedSceneValue(\.selectedTab, $selectedTab)
    }
}

struct AppCommands: Commands {
    @FocusedBinding(\.selectedTab) var selectedTab

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Conversation") {
                NotificationCenter.default.post(name: .newConversation, object: nil)
            }.keyboardShortcut("n", modifiers: .command)
            Button("Clear Display") {
                NotificationCenter.default.post(name: .clearDisplay, object: nil)
            }.keyboardShortcut("k", modifiers: .command)
            Divider()
            Button("Chat") { selectedTab = .chat }.keyboardShortcut("1", modifiers: .command)
            Button("Dashboard") { selectedTab = .dashboard }.keyboardShortcut("2", modifiers: .command)
            Button("Sessions") { selectedTab = .sessions }.keyboardShortcut("3", modifiers: .command)
        }
    }
}

struct SelectedTabKey: FocusedValueKey {
    typealias Value = Binding<AppTab>
}

extension FocusedValues {
    var selectedTab: Binding<AppTab>? {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}
