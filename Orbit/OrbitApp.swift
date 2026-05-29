import SwiftUI
import SwiftData

@main
struct OrbitApp: App {
    var body: some Scene {
        WindowGroup {
            RootSplitView()
        }
        .modelContainer(for: [
            Workspace.self,
            Project.self,
            Issue.self,
            Label.self,
            SavedView.self,
        ])
    }
}
