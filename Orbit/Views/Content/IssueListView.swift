import SwiftUI
import SwiftData

/// List of issues scoped to the selected project, filtered and sorted in Swift.
/// Approach: reads project.unwrappedIssues directly (no @Query with parameterized predicate)
/// — consistent with Phase 3 in-memory filtering and avoids the @Query-init-once pitfall.
struct IssueListView: View {
    let project: Project
    @Environment(Selection.self) private var selection
    @Environment(\.modelContext) private var context

    private var sortedIssues: [Issue] {
        project.unwrappedIssues.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        @Bindable var sel = selection
        Group {
            if sortedIssues.isEmpty {
                ContentUnavailableView(
                    "No Issues",
                    systemImage: "tray",
                    description: Text("Press + or ⌘N to create your first issue.")
                )
            } else {
                List(selection: $sel.selectedIssue) {
                    ForEach(sortedIssues) { issue in
                        IssueRow(issue: issue)
                            .tag(issue)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    if selection.selectedIssue?.persistentModelID == issue.persistentModelID {
                                        selection.selectedIssue = nil
                                    }
                                    context.delete(issue)
                                    try? context.save()
                                }
                            }
                    }
                }
            }
        }
    }
}
