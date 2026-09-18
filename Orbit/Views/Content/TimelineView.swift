import SwiftUI
import SwiftData

/// Timeline view (Fase 2, shell 1b): rows = issues, columns = weeks. Receives
/// a pre-filtered [Issue] from ContentPaneView — same contract as
/// IssueListView/IssueBoardView.
///
/// Layout decisions (see README §8 "Timeline"):
/// - The global week range runs from the oldest `createdAt` to the farthest
///   "end" (`dueDate`, or `updatedAt` + 2 weeks when there's no due date),
///   rounded out to whole week boundaries. A single issue (or a very tight
///   cluster) would otherwise collapse the grid to 1-2 columns, so the range
///   is padded to a minimum of `minWeekCount` weeks.
/// - Week columns normally stretch to fill the available width (matching the
///   HTML prototype's `flex:1` columns). Only when that would squeeze columns
///   below a readable minimum does the view fall back to a fixed column
///   width and scroll the whole grid (header + rows) horizontally together —
///   the 300px issue column is not independently pinned in that case, since
///   SwiftUI has no cheap native primitive for a column pinned inside a
///   view that's itself horizontally scrolling. In the common case (range
///   fits the pane) the header simply sits above the vertical ScrollView, so
///   it reads as sticky without any pinning machinery.
struct TimelineView: View {
    let issues: [Issue]
    @Environment(Selection.self) private var selection

    private let titleColumnWidth: CGFloat = 300
    private let minWeekColumnWidth: CGFloat = 64
    private let minWeekCount = 6
    private let rowSpacing: CGFloat = 2

    var body: some View {
        Group {
            if issues.isEmpty {
                ContentUnavailableView {
                    SwiftUI.Label("No Issues", systemImage: "chart.bar.doc.horizontal")
                        .font(Nocturne.Font_.rowTitle)
                } description: {
                    Text("Press ⌘N to create an issue, or clear your filters.")
                        .font(Nocturne.Font_.meta)
                        .foregroundStyle(Nocturne.textDim)
                }
                // Greedy so the empty state stays centered in the FULL pane
                // instead of hugging its own size — a non-greedy empty state
                // here is what let the whole content column collapse upward
                // and leave a huge gap above the ProjectHeader (see
                // ContentPaneView's ProjectContentView, which now anchors to
                // .top but still needs its children to actually fill height).
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                    let weeks = weekColumns
                    let laneWidth = max(geo.size.width - titleColumnWidth, 0)
                    let naturalColWidth = weeks.isEmpty ? minWeekColumnWidth : laneWidth / CGFloat(weeks.count)
                    let needsHorizontalScroll = naturalColWidth < minWeekColumnWidth
                    let colWidth = needsHorizontalScroll ? minWeekColumnWidth : naturalColWidth
                    let gridWidth = titleColumnWidth + colWidth * CGFloat(weeks.count)

                    let grid = TimelineGrid(
                        issues: issues,
                        weeks: weeks,
                        range: timelineRange,
                        titleColumnWidth: titleColumnWidth,
                        colWidth: colWidth
                    )
                    .frame(width: needsHorizontalScroll ? gridWidth : nil)

                    if needsHorizontalScroll {
                        ScrollView(.horizontal, showsIndicators: true) { grid }
                    } else {
                        grid
                    }
                }
                .padding(.horizontal, DS.Space.lg)
            }
        }
        .background(Nocturne.bg)
    }

    // MARK: - Range & columns

    /// Global date range for the grid, rounded out to week boundaries.
    private var timelineRange: ClosedRange<Date> {
        let cal = Calendar.current
        let now = Date.now

        let starts = issues.map(\.createdAt)
        let ends = issues.map(effectiveEnd)

        let earliest = starts.min() ?? now
        let latest = max(ends.max() ?? now, earliest)

        let start = startOfWeek(earliest, calendar: cal)
        var end = cal.date(byAdding: .weekOfYear, value: 1, to: startOfWeek(latest, calendar: cal)) ?? latest

        let weeksBetween = cal.dateComponents([.weekOfYear], from: start, to: end).weekOfYear ?? 0
        if weeksBetween < minWeekCount {
            end = cal.date(byAdding: .weekOfYear, value: minWeekCount - weeksBetween, to: end) ?? end
        }
        return start...end
    }

    private var weekColumns: [Date] {
        let cal = Calendar.current
        let range = timelineRange
        var result: [Date] = []
        var cursor = range.lowerBound
        while cursor < range.upperBound {
            result.append(cursor)
            guard let next = cal.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func startOfWeek(_ date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    /// The bar's right edge: `dueDate` when set, otherwise `updatedAt` + 2 weeks
    /// (per README §8 — chosen over leaving the bar visually open-ended, so
    /// every issue always renders a well-defined bar).
    private func effectiveEnd(for issue: Issue) -> Date {
        if let due = issue.dueDate { return due }
        let cal = Calendar.current
        return cal.date(byAdding: .weekOfYear, value: 2, to: issue.updatedAt) ?? issue.updatedAt
    }
}

// MARK: - Grid (header + scrollable rows)

private struct TimelineGrid: View {
    let issues: [Issue]
    let weeks: [Date]
    let range: ClosedRange<Date>
    let titleColumnWidth: CGFloat
    let colWidth: CGFloat

    @Environment(Selection.self) private var selection

    private var laneWidth: CGFloat { colWidth * CGFloat(weeks.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TimelineHeader(weeks: weeks, titleColumnWidth: titleColumnWidth, colWidth: colWidth)

            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(issues) { issue in
                            TimelineRow(
                                issue: issue,
                                weeks: weeks,
                                range: range,
                                titleColumnWidth: titleColumnWidth,
                                laneWidth: laneWidth,
                                colWidth: colWidth,
                                isSelected: issue.persistentModelID == selection.selectedIssue?.persistentModelID,
                                onSelect: { selection.selectedIssue = issue }
                            )
                        }
                    }
                    .padding(.vertical, 6)

                    todayLine
                }
            }
        }
    }

    /// 1pt vertical marker at "now", fading at top/bottom, overlaid at the
    /// correct fractional position across the lane. Hidden when "now" falls
    /// outside the visible range.
    @ViewBuilder
    private var todayLine: some View {
        let now = Date.now
        if range.contains(now) {
            let total = range.upperBound.timeIntervalSince(range.lowerBound)
            let fraction = total > 0 ? CGFloat(now.timeIntervalSince(range.lowerBound) / total) : 0
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Nocturne.accent, location: 0.08),
                    .init(color: Nocturne.accent, location: 0.92),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .offset(x: titleColumnWidth + laneWidth * fraction)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Header

private struct TimelineHeader: View {
    let weeks: [Date]
    let titleColumnWidth: CGFloat
    let colWidth: CGFloat

    /// Column left-border hex from the mock (`#1E2130`) — the same value
    /// Theme.swift's card elevation border uses inline, but there's no shared
    /// token for "week-column divider" specifically, so it's a local literal.
    private let columnBorder = Color(hex: "#1E2130")

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            SectionCaps(text: "Issue")
                .frame(width: titleColumnWidth, alignment: .leading)

            ForEach(weeks, id: \.self) { week in
                Text(Self.weekLabelFormat(week))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Nocturne.Neutral.n700)  // #595D6C
                    .frame(width: colWidth, alignment: .leading)
                    .padding(.leading, 7)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(columnBorder).frame(width: 1)
                    }
            }
        }
        .padding(.vertical, 8)
        .background(Nocturne.bg)
    }

    private static func weekLabelFormat(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Row

private struct TimelineRow: View {
    let issue: Issue
    let weeks: [Date]
    let range: ClosedRange<Date>
    let titleColumnWidth: CGFloat
    let laneWidth: CGFloat
    let colWidth: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    private var isClosed: Bool { issue.status == .done || issue.status == .cancelled }

    private var titleColor: Color {
        if issue.title.isEmpty { return Nocturne.textDim }
        return isClosed ? Nocturne.textDim : Nocturne.text
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            titleColumn
            laneTrack
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }

    // MARK: Title column

    private var titleColumn: some View {
        HStack(spacing: 8) {
            Image(systemName: issue.status.glyph)
                .font(.system(size: 13))
                .foregroundStyle(issue.status.color)
                .frame(width: 14)

            Text(issue.title.isEmpty ? "Untitled" : issue.title)
                .font(.system(size: 12.5))
                .foregroundStyle(titleColor)
                .strikethrough(issue.status == .cancelled)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.leading, 6)
        .frame(width: titleColumnWidth, height: 30, alignment: .leading)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                    .fill(isSelected ? Nocturne.accentSel : (isHovering ? Nocturne.surface : .clear))
                if isSelected {
                    Rectangle().fill(Nocturne.accent).frame(width: 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.row))
        )
    }

    // MARK: Lane track

    private var laneTrack: some View {
        ZStack(alignment: .topLeading) {
            // Week gridlines
            HStack(spacing: 0) {
                ForEach(weeks, id: \.self) { _ in
                    Rectangle()
                        .fill(Nocturne.rowLine)
                        .frame(width: 1)
                        .frame(width: colWidth, alignment: .leading)
                }
            }

            bar
        }
        .frame(width: laneWidth, height: 22)
    }

    private var bar: some View {
        let start = clampedFraction(issue.createdAt)
        let end = clampedFraction(effectiveEnd)
        let left = laneWidth * start
        let width = max(laneWidth * (end - start), 32)

        return RoundedRectangle(cornerRadius: 6)
            .fill(barBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Nocturne.accent : barBorder, lineWidth: isSelected ? 1.5 : 1)
            )
            .frame(width: width, height: 16)
            .overlay(alignment: .leading) {
                Text(issue.title)
                    .font(.system(size: 10))
                    .foregroundStyle(barForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)
            }
            .offset(x: left, y: 3)
    }

    private var effectiveEnd: Date {
        if let due = issue.dueDate { return due }
        return Calendar.current.date(byAdding: .weekOfYear, value: 2, to: issue.updatedAt) ?? issue.updatedAt
    }

    private func clampedFraction(_ date: Date) -> CGFloat {
        let total = range.upperBound.timeIntervalSince(range.lowerBound)
        guard total > 0 else { return 0 }
        let clamped = min(max(date, range.lowerBound), range.upperBound)
        return CGFloat(clamped.timeIntervalSince(range.lowerBound) / total)
    }

    // Bar colors — README §8: In Progress uses the accent as a translucent
    // fill with a solid accent border; Done and everything else share the
    // neutral treatment but with different tints per the spec table.
    private var barBackground: Color {
        switch issue.status {
        case .inProgress: Nocturne.accent.opacity(0.32)
        case .done:       Nocturne.accentText.opacity(0.18)
        default:          Nocturne.Neutral.n600.opacity(0.18)
        }
    }

    private var barBorder: Color {
        switch issue.status {
        case .inProgress: Nocturne.accent
        default:          Color(hex: "#2F3240")
        }
    }

    private var barForeground: Color {
        switch issue.status {
        case .inProgress: Nocturne.text
        default:          Nocturne.Neutral.n500
        }
    }
}
