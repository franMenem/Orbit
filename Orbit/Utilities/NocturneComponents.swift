import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// Nocturne — small shared components, consumed by IssueRow,
// IssueCard, IssueDetailView and the grouped list headers.
// ─────────────────────────────────────────────────────────────────────────────

/// 3-bar signal mark — replaces the colored priority arrows.
/// Width 2.5, heights 4/6.5/9, gap 1.5, radius 1, bottom-aligned. The active
/// bars (`priority.barCount`) take `priority.color`; the inactive ones stay
/// at `Nocturne.dashed`.
struct PriorityBars: View {
    let priority: IssuePriority
    private let heights: [CGFloat] = [4, 6.5, 9]

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < priority.barCount ? priority.color : Nocturne.dashed)
                    .frame(width: 2.5, height: height)
            }
        }
        .frame(height: 9)
        .accessibilityLabel("Priority \(priority.displayName)")
    }
}

/// 1pt horizontal line that fades out at the ends — Nocturne's visual
/// signature. Used in the list's group header and between sections of the
/// detail view.
struct FadingRule: View {
    var color: Color = Nocturne.divider
    var inset: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            let stop = min(inset / max(geo.size.width, 1), 0.45)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: color, location: stop),
                    .init(color: color, location: 1 - stop),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        }
        .frame(height: 1)
    }
}
