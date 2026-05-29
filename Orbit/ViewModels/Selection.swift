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
            }
        }
    }
    var selectedIssue: Issue?
}
