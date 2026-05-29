import SwiftUI

/// Presentational card for the Kanban board. Compact, draggable via parent.
struct IssueCard: View {
    let issue: Issue
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(issue.title.isEmpty ? "Untitled" : issue.title)
                .font(.subheadline)
                .lineLimit(2)

            HStack(spacing: 6) {
                Image(systemName: issue.priority.symbolName)
                    .font(.caption)
                    .foregroundStyle(priorityColor)

                if let due = issue.dueDate {
                    SwiftUI.Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(issue.unwrappedLabels.prefix(2)) { label in
                        LabelChip(name: label.name, colorHex: label.colorHex)
                    }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 1.5 : 0.5)
        )
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
