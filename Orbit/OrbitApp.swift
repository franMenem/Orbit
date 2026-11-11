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
        // OrbitTests uses the app as its test host: under XCTest we show no
        // windows or Dock icon (the app runs invisibly for the duration of the test run).
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
