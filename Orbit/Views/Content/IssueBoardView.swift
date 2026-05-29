import SwiftUI
import SwiftData

/// Kanban board with one column per IssueStatus.
/// Issues are grouped in Swift from project.unwrappedIssues — no relationship predicates.
/// DnD: draggable payload = issue.id.uuidString (String); drop sets issue.status.
struct IssueBoardView: View {
    let project: Project
    @Environment(Selection.self) private var selection
    @Environment(\.modelContext) private var context

    private var issuesByStatus: [IssueStatus: [Issue]] {
        Dictionary(grouping: project.unwrappedIssues, by: \.status)
    }

    private var orderedStatuses: [IssueStatus] {
        IssueStatus.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(orderedStatuses, id: \.self) { status in
                    BoardColumn(
                        status: status,
                        issues: (issuesByStatus[status] ?? []).sorted { $0.createdAt > $1.createdAt },
                        selectedIssue: selection.selectedIssue,
                        onSelect: { selection.selectedIssue = $0 },
                        onDrop: { handleDrop(uuidString: $0, to: status) }
                    )
                }
            }
            .padding()
        }
    }

    private func handleDrop(uuidString: String, to targetStatus: IssueStatus) -> Bool {
        guard let uuid = UUID(uuidString: uuidString),
              let issue = project.unwrappedIssues.first(where: { $0.id == uuid }),
              issue.status != targetStatus
        else { return false }
        issue.status = targetStatus
        issue.updatedAt = .now
        try? context.save()
        return true
    }
}

private struct BoardColumn: View {
    let status: IssueStatus
    let issues: [Issue]
    let selectedIssue: Issue?
    let onSelect: (Issue) -> Void
    let onDrop: (String) -> Bool

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(status.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(issues.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(issues) { issue in
                        IssueCard(
                            issue: issue,
                            isSelected: issue.persistentModelID == selectedIssue?.persistentModelID
                        )
                        .draggable(issue.id.uuidString)
                        .onTapGesture { onSelect(issue) }
                        .contextMenu {
                            Menu("Move to") {
                                ForEach(IssueStatus.allCases.sorted { $0.sortOrder < $1.sortOrder }, id: \.self) { s in
                                    if s != issue.status {
                                        Button(s.displayName) { _ = onDrop(issue.id.uuidString) }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(width: 230)
        .padding(10)
        .background(isTargeted ? Color.accentColor.opacity(0.06) : Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isTargeted ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isTargeted ? 1.5 : 0.5)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first else { return false }
            return onDrop(first)
        } isTargeted: { isTargeted = $0 }
    }
}
