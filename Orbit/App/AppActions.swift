import Foundation
import Observation

/// Shared command surface owned by OrbitApp, injected via .environment.
/// Contains only signals (flags) — no business logic. Views observe signals,
/// execute the action with full context access, then set the flag back to false.
///
/// NOTE: Owned in OrbitApp rather than RootSplitView because OrbitCommands
/// lives at the Scene level (outside the view hierarchy) and needs it before
/// any view is created. Still a single instance — the "one owner" rule holds.
@Observable
final class AppActions {
    /// ⌘N — create a new issue in the selected project (or seeded default).
    var createIssueSignal = false
    /// Sidebar shortcut — create a new project.
    var createProjectSignal = false
    /// Sidebar shortcut — create a new workspace.
    var createWorkspaceSignal = false
    /// ⌘F — focus the FilterBar search field.
    var focusSearchSignal = false
    /// ⌘K — show the command palette overlay.
    var showCommandPalette = false
    /// ⌘1/⌘2 — switch content view mode. Consumed+cleared by ContentPaneView.
    var pendingMode: ContentViewMode? = nil
    /// Set by ContentPaneView after creating an issue so IssueDetailView auto-focuses the title.
    var focusNewIssueTitle = false
}
