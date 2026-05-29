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
        .modelContainer(ContainerFactory.make())
        #if os(macOS)
        .commands {
            OrbitCommands(actions: appActions)
        }
        #endif
    }
}
