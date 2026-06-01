import SwiftUI

/// Presentational card for the Kanban board. Compact, draggable via parent.
struct IssueCard: View {
    let issue: Issue
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.xs) {
                if issue.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .rotationEffect(.degrees(45))
                }
                Text(issue.title.isEmpty ? "Untitled" : issue.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }

            if issue.priority != .none || issue.dueDate != nil || !issue.unwrappedLabels.isEmpty {
                HStack(spacing: DS.Space.sm) {
                    if issue.priority != .none {
                        Image(systemName: issue.priority.symbolName)
                            .font(.caption)
                            .foregroundStyle(issue.priority.color)
                    }
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
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isSelected ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: DS.Radius.control)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.control)
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                        lineWidth: isSelected ? 1.5 : 0.5)
        )
    }
}
