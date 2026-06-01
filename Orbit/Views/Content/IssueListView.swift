import SwiftUI
import SwiftData

/// List of issues. Receives pre-filtered, pre-sorted [Issue] from ContentPaneView.
/// Arrow-key navigation via List(selection:); ⌫/Delete with confirmationDialog.
struct IssueListView: View {
    let issues: [Issue]
    @Environment(Selection.self) private var selection
    @Environment(\.modelContext) private var context
    @State private var showDeleteConfirm = false

    var body: some View {
        @Bindable var sel = selection
        Group {
            if issues.isEmpty {
                ContentUnavailableView(
                    "No Issues",
                    systemImage: "tray",
                    description: Text("Press ⌘N to create an issue, or clear your filters.")
                )
            } else {
                ScrollViewReader { proxy in
                    List(selection: $sel.selectedIssue) {
                        ForEach(issues) { issue in
                            IssueRow(issue: issue)
                                .tag(issue)
                                .id(issue.id)
                                .contextMenu {
                                    Button {
                                        issue.isPinned.toggle()
                                        try? context.save()
                                    } label: {
                                        SwiftUI.Label(
                                            issue.isPinned ? "Unpin" : "Pin to top",
                                            systemImage: issue.isPinned ? "pin.slash" : "pin"
                                        )
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        sel.selectedIssue = issue
                                        showDeleteConfirm = true
                                    }
                                }
                        }
                    }
                    .onDeleteCommand {
                        if selection.selectedIssue != nil { showDeleteConfirm = true }
                    }
                    // Keep the selected issue in view — especially a freshly
                    // created one, which would otherwise be off-screen.
                    .onChange(of: selection.selectedIssue) {
                        guard let id = selection.selectedIssue?.id else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(selection.selectedIssue?.title.isEmpty == false ? selection.selectedIssue!.title : "Untitled")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteSelected() }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private func deleteSelected() {
        guard let issue = selection.selectedIssue else { return }
        selection.selectedIssue = nil
        // Relationship cleanup: SwiftData cascade rules handle project.issues,
        // but we manually clear label references since deleteRule is .nullify.
        issue.labels?.forEach { label in
            label.issues?.removeAll { $0.persistentModelID == issue.persistentModelID }
        }
        context.delete(issue)
        try? context.save()
    }
}
