import SwiftUI

@main
struct ClaudeDashboardApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appViewModel)
                .task { await appViewModel.bootstrap() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 700)
        .windowResizability(.contentMinSize)
        .commands { AppCommands() }
    }
}
