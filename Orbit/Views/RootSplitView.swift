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
            ContentPaneView()
        } detail: {
            IssueDetailView()
        }
        .environment(selection)
    }
}

