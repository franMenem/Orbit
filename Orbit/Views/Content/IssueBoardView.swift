import SwiftUI
import SwiftData

/// Kanban board. Receives a pre-filtered [Issue] from ContentPaneView; groups by status in Swift.
/// DnD: payload = issue.id.uuidString; drop handler looks up via context.fetch (scalar predicate only).
struct IssueBoardView: View {
    let issues: [Issue]
    @Environment(Selection.self) private var selection
    @Environment(\.modelContext) private var context

    private var issuesByStatus: [IssueStatus: [Issue]] {
        Dictionary(grouping: issues, by: \.status)
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
                        issues: issuesByStatus[status] ?? [],
                        selectedIssue: selection.selectedIssue,
                        onSelect: { selection.selectedIssue = $0 },
                        onDrop: { handleDrop(uuidString: $0, to: status) }
                    )
                }
            }
            .padding()
        }
        .background(Nocturne.bg)
    }

    private func handleDrop(uuidString: String, to targetStatus: IssueStatus) -> Bool {
        guard let uuid = UUID(uuidString: uuidString) else { return false }
        // Scalar predicate on own field — no to-many traversal, CloudKit-safe.
        let descriptor = FetchDescriptor<Issue>(predicate: #Predicate<Issue> { $0.id == uuid })
        guard let issue = (try? context.fetch(descriptor))?.first,
              issue.status != targetStatus else { return false }
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
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: status.glyph)
                    .font(.caption)
                    .foregroundStyle(status.color)
                Text(status.displayName)
                    .font(Nocturne.Font_.inter(12, .semibold))
                    .foregroundStyle(Nocturne.text)
                Spacer()
                Text("\(issues.count)")
                    .font(Nocturne.Font_.chip.weight(.medium))
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(status.tint, in: Capsule())
            }
            .padding(.horizontal, 2)

            if issues.isEmpty {
                emptyDropTarget
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 9) {
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
        }
        .frame(width: 236)
        .padding(10)
        .background(Nocturne.bgDeep, in: RoundedRectangle(cornerRadius: Nocturne.Radius.column))
        .overlay(
            RoundedRectangle(cornerRadius: Nocturne.Radius.column)
                .stroke(isTargeted ? Nocturne.accent : Color(hex: "#1E2130"), lineWidth: isTargeted ? 1.5 : 1)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let first = items.first else { return false }
            return onDrop(first)
        } isTargeted: { isTargeted = $0 }
    }

    private var emptyDropTarget: some View {
        RoundedRectangle(cornerRadius: Nocturne.Radius.row)
            .strokeBorder(Nocturne.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(height: 72)
            .overlay(
                Text("Arrastrá un issue acá")
                    .font(Nocturne.Font_.meta)
                    .foregroundStyle(Nocturne.textFaint)
            )
    }
}
