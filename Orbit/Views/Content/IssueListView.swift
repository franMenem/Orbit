import SwiftUI
import SwiftData

/// List of issues. Receives pre-filtered, pre-sorted [Issue] from ContentPaneView.
/// Grouped by IssueStatus (one section per status with ≥1 issue, ordered by
/// `sortOrder`), with a sticky, collapsible header per group.
/// Arrow-key navigation via List(selection:); ⌫/Delete with confirmationDialog.
struct IssueListView: View {
    let issues: [Issue]
    @Environment(Selection.self) private var selection
    @Environment(\.modelContext) private var context
    @State private var showDeleteConfirm = false
    @State private var collapsedGroups: Set<IssueStatus> = []

    /// Statuses present in `issues`, ordered by `IssueStatus.sortOrder`.
    private var groupedStatuses: [IssueStatus] {
        let present = Set(issues.map(\.status))
        return IssueStatus.allCases
            .filter { present.contains($0) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var issuesByStatus: [IssueStatus: [Issue]] {
        Dictionary(grouping: issues, by: \.status)
    }

    var body: some View {
        @Bindable var sel = selection
        Group {
            if issues.isEmpty {
                ContentUnavailableView {
                    SwiftUI.Label("No Issues", systemImage: "tray")
                        .font(Nocturne.Font_.rowTitle)
                } description: {
                    Text("Press ⌘N to create an issue, or clear your filters.")
                        .font(Nocturne.Font_.meta)
                        .foregroundStyle(Nocturne.textDim)
                }
                // Greedy — see TimelineView's matching empty-state fix for why.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(selection: $sel.selectedIssue) {
                        ForEach(groupedStatuses, id: \.self) { status in
                            let groupIssues = issuesByStatus[status] ?? []
                            Section {
                                if !collapsedGroups.contains(status) {
                                    ForEach(groupIssues) { issue in
                                        IssueRow(issue: issue)
                                            .tag(issue)
                                            .id(issue.id)
                                            .listRowInsets(EdgeInsets(top: 1, leading: 10, bottom: 1, trailing: 10))
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
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
                            } header: {
                                GroupHeader(
                                    status: status,
                                    count: groupIssues.count,
                                    isCollapsed: collapsedGroups.contains(status)
                                ) {
                                    toggleCollapse(status)
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Nocturne.bg)
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

    private func toggleCollapse(_ status: IssueStatus) {
        if collapsedGroups.contains(status) {
            collapsedGroups.remove(status)
        } else {
            collapsedGroups.insert(status)
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

/// Sticky section header — status glyph + name + count + a rule fading into
/// the trailing edge. Click toggles the group's collapsed state.
private struct GroupHeader: View {
    let status: IssueStatus
    let count: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Nocturne.textFaint)
                    .frame(width: 9)
                Image(systemName: status.glyph)
                    .font(.system(size: 14))
                    .foregroundStyle(status.color)
                Text(status.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Nocturne.text)
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundStyle(Nocturne.Neutral.n700)
                FadingRule()
            }
            .padding(.top, 12)
            .padding(.horizontal, 18)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Nocturne.bg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
