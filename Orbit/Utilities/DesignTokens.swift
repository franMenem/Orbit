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
    }
}

// MARK: - IssueStatus visual style

extension IssueStatus {
    /// Semantic tint — communicates state at a glance. SwiftUI system colors
    /// adapt to light/dark automatically.
    var color: Color {
        switch self {
        case .backlog:    .secondary
        case .todo:       .blue
        case .inProgress: .orange
        case .done:       .green
        case .cancelled:  .pink
        }
    }

    /// Linear-style progress glyph for the status.
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
    /// Single source of truth for priority color (was duplicated in IssueRow/IssueCard).
    var color: Color {
        switch self {
        case .urgent: .red
        case .high:   .orange
        case .medium: .yellow
        case .low:    .blue
        case .none:   .secondary
        }
    }
}
