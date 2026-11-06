import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

@main
struct OrbitApp: App {
    @State private var appActions = AppActions()

    init() {
        #if os(macOS)
        // OrbitTests usa la app como test host: bajo XCTest no mostramos
        // ventanas ni Dock icon (la app corre invisible mientras dura el test run).
        if InboxImporter.isRunningUnderTests {
            NSApplication.shared.setActivationPolicy(.prohibited)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootSplitView()
                .environment(appActions)
        }
        .modelContainer(ContainerFactory.make())
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            OrbitCommands(actions: appActions)
        }
        #endif
    }
}
