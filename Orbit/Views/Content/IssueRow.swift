import SwiftUI

/// Presentational row for the List view. Reads an Issue; tap is handled by the parent List.
struct IssueRow: View {
    let issue: Issue

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: issue.priority.symbolName)
                .foregroundStyle(priorityColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title.isEmpty ? "Untitled" : issue.title)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    StatusPill(status: issue.status)
                    if let due = issue.dueDate {
                        SwiftUI.Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(issue.unwrappedLabels.prefix(3)) { label in
                        LabelChip(name: label.name, colorHex: label.colorHex)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var priorityColor: Color {
        switch issue.priority {
        case .urgent: .red
        case .high:   .orange
        case .medium: .yellow
        case .low:    .blue
        case .none:   .secondary
        }
    }
}

struct StatusPill: View {
    let status: IssueStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
