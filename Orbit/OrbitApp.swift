import SwiftUI
import SwiftData

@main
struct OrbitApp: App {
    @State private var appActions = AppActions()

    var body: some Scene {
        WindowGroup {
            RootSplitView()
                .environment(appActions)
        }
        .modelContainer(for: [
            Workspace.self,
            Project.self,
            Issue.self,
            Label.self,
            SavedView.self,
        ])
        .commands {
            OrbitCommands(actions: appActions)
        }
    }
}
