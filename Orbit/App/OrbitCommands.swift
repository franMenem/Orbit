#if os(macOS)
import SwiftUI

struct OrbitCommands: Commands {
    let actions: AppActions

    var body: some Commands {
        // File menu — replaces default "New" group
        CommandGroup(replacing: .newItem) {
            Button("New Issue") {
                actions.createIssueSignal = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Project") {
                actions.createProjectSignal = true
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New Workspace") {
                actions.createWorkspaceSignal = true
            }
        }

        // View menu
        CommandMenu("View") {
            Button("List") {
                actions.pendingMode = .list
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Board") {
                actions.pendingMode = .board
            }
            .keyboardShortcut("2", modifiers: .command)

            Divider()

            Button("Search") {
                actions.focusSearchSignal = true
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Command Palette") {
                actions.showCommandPalette = true
            }
            .keyboardShortcut("k", modifiers: .command)
        }
    }
}
#endif
