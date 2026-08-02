import SwiftUI
import SwiftData

/// Presentational row for the List view. Reads an Issue; tap is handled by the parent List.
///
/// Nocturne structure: [status glyph] [title + metadata] [AI button] [code].
/// Selection is drawn by this view itself (accentSel fill + 2px accent bar) —
/// the parent List suppresses its native highlight via `.listRowBackground(.clear)`.
struct IssueRow: View {
    let issue: Issue
    @Environment(Selection.self) private var selection

    @State private var isHoveringRow = false
    @State private var isHoveringAI = false

    private var isSelected: Bool {
        selection.selectedIssue?.persistentModelID == issue.persistentModelID
    }

    private var isClosed: Bool {
        issue.status == .done || issue.status == .cancelled
    }

    private var titleColor: Color {
        if issue.title.isEmpty { return Nocturne.textDim }
        return isClosed ? Nocturne.textDim : Nocturne.text
    }

    var body: some View {
        HStack(alignment: .center, spacing: DS.Space.sm) {
            // Status glyph — colored, communicates state at a glance
            Image(systemName: issue.status.glyph)
                .font(.system(size: 15))
                .foregroundStyle(issue.status.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                titleRow
                metadataRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            aiButton

            codeLabel
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 44, alignment: .center)
        .contentShape(Rectangle())
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                    .fill(isSelected ? Nocturne.accentSel : (isHoveringRow ? Nocturne.surface : Color.clear))
                if isSelected {
                    Rectangle().fill(Nocturne.accent).frame(width: 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.row))
        )
        .animation(.easeInOut(duration: 0.12), value: isHoveringRow)
        .onHover { isHoveringRow = $0 }
    }

    // MARK: - Title

    private var titleRow: some View {
        HStack(spacing: 4) {
            if issue.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Nocturne.accent)
            }
            if issue.title.isEmpty {
                Text("Untitled")
                    .italic()
            } else {
                Text(issue.title)
                    .strikethrough(issue.status == .cancelled)
            }
        }
        .font(Nocturne.Font_.rowTitle)
        .foregroundStyle(titleColor)
        .lineLimit(1)
    }

    // MARK: - Metadata

    private var metadataRow: some View {
        HStack(spacing: DS.Space.sm) {
            // Priority (only when set — reduces noise)
            if issue.priority != .none {
                HStack(spacing: 4) {
                    PriorityBars(priority: issue.priority)
                    Text(issue.priority.displayName)
                        .font(Nocturne.Font_.meta)
                        .foregroundStyle(issue.priority.color)
                }
            }

            ForEach(issue.unwrappedLabels.prefix(3)) { label in
                LabelChip(name: label.name, colorHex: label.colorHex)
            }

            Text(Self.relativeTimeFormatter.localizedString(for: issue.updatedAt, relativeTo: .now))
                .font(Nocturne.Font_.meta)
                .foregroundStyle(Nocturne.textFaint)
        }
    }

    private static let relativeTimeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    // MARK: - AI button

    private var aiButton: some View {
        Button {
            ClipboardService.copyIssueForAI(issue)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11))
                Text("AI")
                    .font(.system(size: 10.5))
            }
            .foregroundStyle(isHoveringAI ? Nocturne.accentText : Nocturne.textMuted)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHoveringAI ? Nocturne.accent : Nocturne.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .opacity(isHoveringAI ? 1 : 0.6)
        .animation(.easeInOut(duration: 0.12), value: isHoveringAI)
        .onHover { isHoveringAI = $0 }
        .help("Copy for AI")
    }

    // MARK: - Code

    private var codeLabel: some View {
        Text(issue.code.isEmpty ? "—" : issue.code)
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(Nocturne.textFaint)
            .frame(minWidth: 44, alignment: .trailing)
    }
}
