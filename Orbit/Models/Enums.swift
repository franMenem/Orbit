import Foundation

enum IssueStatus: String, Codable, CaseIterable, Hashable {
    case backlog
    case todo
    case inProgress
    case done
    case cancelled

    var displayName: String {
        switch self {
        case .backlog:    "Backlog"
        case .todo:       "Todo"
        case .inProgress: "In Progress"
        case .done:       "Done"
        case .cancelled:  "Cancelled"
        }
    }

    var sortOrder: Int {
        switch self {
        case .backlog:    0
        case .todo:       1
        case .inProgress: 2
        case .done:       3
        case .cancelled:  4
        }
    }
}

enum IssuePriority: Int, Codable, CaseIterable, Comparable, Hashable {
    case none   = 0
    case low    = 1
    case medium = 2
    case high   = 3
    case urgent = 4

    static func < (lhs: IssuePriority, rhs: IssuePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .none:   "None"
        case .low:    "Low"
        case .medium: "Medium"
        case .high:   "High"
        case .urgent: "Urgent"
        }
    }

    var symbolName: String {
        switch self {
        case .none:   "minus"
        case .low:    "arrow.down"
        case .medium: "arrow.right"
        case .high:   "arrow.up"
        case .urgent: "exclamationmark.2"
        }
    }
}
