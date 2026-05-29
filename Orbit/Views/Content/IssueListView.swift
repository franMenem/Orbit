import SwiftUI
import SwiftData

/// List of issues. Receives a pre-filtered, pre-sorted [Issue] from ContentPaneView.
struct IssueListView: View {
    let issues: [Issue]
    @Environment(Selection.self) private var selection
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var sel = selection
        Group {
            if issues.isEmpty {
                ContentUnavailableView(
                    "No Issues",
                    systemImage: "tray",
                    description: Text("Press + to create an issue, or clear your filters.")
                )
            } else {
                List(selection: $sel.selectedIssue) {
                    ForEach(issues) { issue in
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
