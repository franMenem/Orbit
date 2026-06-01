import SwiftUI

/// Presentational row for the List view. Reads an Issue; tap is handled by the parent List.
struct IssueRow: View {
    let issue: Issue

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.md) {
            // Status glyph — colored, communicates state at a glance
            Image(systemName: issue.status.glyph)
                .font(.body)
                .foregroundStyle(issue.status.color)
                .frame(width: 18)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                // Title row — larger, clear hierarchy
                HStack(spacing: DS.Space.xs) {
                    if issue.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .rotationEffect(.degrees(45))
                    }
                    if issue.title.isEmpty {
                        Text("Untitled")
                            .font(.body)
                            .italic()
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(issue.title)
                            .font(.body)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                }

                // Metadata row — secondary
                HStack(spacing: DS.Space.sm) {
                    // Priority (only when set — reduces noise)
                    if issue.priority != .none {
                        SwiftUI.Label {
                            Text(issue.priority.displayName)
                        } icon: {
                            Image(systemName: issue.priority.symbolName)
                        }
                        .font(.caption)
                        .foregroundStyle(issue.priority.color)
                        .labelStyle(.titleAndIcon)
                    }

                    if let due = issue.dueDate {
                        SwiftUI.Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(issue.unwrappedLabels.prefix(3)) { label in
                        LabelChip(name: label.name, colorHex: label.colorHex)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Space.sm)
        .padding(.horizontal, DS.Space.xs)
        // Uniform minimum height so rows without metadata (e.g. a brand-new
        // "Untitled" issue) match rows that have a metadata line.
        .frame(minHeight: 44, alignment: .center)
    }
}

/// Colored status pill — the tint is the signal.
struct StatusPill: View {
    let status: IssueStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.glyph)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, DS.Space.sm)
        .padding(.vertical, 3)
        .foregroundStyle(status.color)
        .background(status.color.opacity(0.14), in: Capsule())
    }
}
