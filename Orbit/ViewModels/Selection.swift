import Foundation
import Observation

/// Shared selection state owned by RootSplitView and injected via .environment.
/// Children read it with @Environment(Selection.self) — never instantiate their own copy.
@Observable
final class Selection {
    var selectedProject: Project? {
        didSet {
            if selectedProject?.persistentModelID != oldValue?.persistentModelID {
                selectedIssue = nil
                selectedSavedView = nil
            }
        }
    }
    var selectedIssue: Issue?
    /// When set, content pane shows workspace-wide issues filtered by this view's config.
    /// Setting this clears selectedProject so the two modes are mutually exclusive.
    var selectedSavedView: SavedView? {
        didSet {
            if selectedSavedView?.persistentModelID != oldValue?.persistentModelID {
                if selectedSavedView != nil { selectedProject = nil }
                selectedIssue = nil
            }
        }
    }
}
