import SwiftUI

/// Central design tokens. Use these instead of arbitrary literals so spacing,
/// radii and type stay consistent across the app.
enum DS {
    // Spacing scale (4-base)
    enum Space {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 24
    }

    // Corner radii
    enum Radius {
        static let chip: CGFloat      = 6
        static let control: CGFloat   = 8
        static let container: CGFloat = 10
        static let sheet: CGFloat     = 14
    }
}

// MARK: - IssueStatus visual style

extension IssueStatus {
    /// Nocturne ramp — intensity, not hue, communicates progress.
    var color: Color {
        switch self {
        case .backlog:    Color(hex: "#75798C")
        case .todo:       Color(hex: "#CFD3E5")
        case .inProgress: Color(hex: "#9184D9")
        case .done:       Color(hex: "#B5ABFC")
        case .cancelled:  Color(hex: "#595D6C")
        }
    }

    /// Background tint for the status pill.
    var tint: Color {
        switch self {
        case .backlog:    color.opacity(0.16)
        case .todo:       color.opacity(0.12)
        case .inProgress: color.opacity(0.16)
        case .done:       color.opacity(0.14)
        case .cancelled:  color.opacity(0.16)
        }
    }

    /// Linear-style progress glyph for the status. Unchanged by the Nocturne
    /// redesign — only colors moved.
    var glyph: String {
        switch self {
        case .backlog:    "circle.dashed"
        case .todo:       "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .done:       "checkmark.circle.fill"
        case .cancelled:  "xmark.circle.fill"
        }
    }
}

// MARK: - IssuePriority visual style

extension IssuePriority {
    /// Nocturne signal-bars color — replaces the old colored arrows.
    var color: Color {
        switch self {
        case .none:   Color(hex: "#4D5060")
        case .low:    Color(hex: "#75798C")
        case .medium: Color(hex: "#B2B6CA")
        case .high:   Color(hex: "#9184D9")
        case .urgent: Color(hex: "#E8415B")
        }
    }

    /// Number of active bars in the `PriorityBars` signal mark.
    var barCount: Int {
        switch self {
        case .none:   0
        case .low:    1
        case .medium: 2
        case .high:   3
        case .urgent: 3
        }
    }
}
