import SwiftUI

/// Presentational card for the Kanban board. Compact, draggable via parent.
/// Nocturne restyle: no system colors for status/priority — everything comes
/// from `Nocturne` tokens, `IssuePriority.color` and the existing `LabelChip`.
struct IssueCard: View {
    let issue: Issue
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.xs) {
                if issue.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Nocturne.accent)
                }
                if issue.title.isEmpty {
                    Text("Untitled")
                        .font(Nocturne.Font_.control.weight(.medium))
                        .italic()
                        .foregroundStyle(Nocturne.textDim)
                        .lineLimit(2)
                } else {
                    Text(issue.title)
                        .font(Nocturne.Font_.control.weight(.medium))
                        .foregroundStyle(Nocturne.text)
                        .lineLimit(2)
                }
            }

            HStack(spacing: DS.Space.xs) {
                PriorityBars(priority: issue.priority)

                ForEach(issue.unwrappedLabels.prefix(2)) { label in
                    LabelChip(name: label.name, colorHex: label.colorHex)
                }

                Spacer(minLength: DS.Space.xs)

                Text(issue.code.isEmpty ? "—" : issue.code)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Nocturne.textFaint)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isHovering ? Nocturne.surfaceHi : Nocturne.surface,
            in: RoundedRectangle(cornerRadius: Nocturne.Radius.row)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                .stroke(isSelected ? Nocturne.accent : Color(hex: "#252838"), lineWidth: 1)
        )
        .onHover { isHovering = $0 }
    }
}
