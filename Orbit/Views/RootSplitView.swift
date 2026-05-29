import SwiftUI

/// Three-column root shell. The SINGLE owner of all shared @Observable state.
/// Holds each shared object as @State and injects it once via .environment.
/// Children NEVER instantiate these objects — they read via @Environment(Type.self).
///
/// Shared state in this phase:
///   - Selection (selectedProject, selectedIssue)
/// Phase 3 adds: FilterState (same pattern — declare here, inject here)
/// Phase 4 adds: AppActions (same pattern)
struct RootSplitView: View {
    @State private var selection = Selection()

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            // Replaced by ContentPaneView in plan 02-02
            ContentPanePlaceholder()
        } detail: {
            IssueDetailView()
        }
        .environment(selection)
    }
}

/// Temporary placeholder — replaced by ContentPaneView in plan 02-02.
private struct ContentPanePlaceholder: View {
    @Environment(Selection.self) private var selection

    var body: some View {
        if let project = selection.selectedProject {
            ContentUnavailableView(
                project.name,
                systemImage: "folder",
                description: Text("\(project.unwrappedIssues.count) issue(s) — list/board coming in plan 02-02")
            )
        } else {
            ContentUnavailableView(
                "No Project Selected",
                systemImage: "folder.badge.questionmark",
                description: Text("Choose a project from the sidebar.")
            )
        }
    }
}
