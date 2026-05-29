import Foundation
import Observation

enum IssueSort: String, CaseIterable {
    case priorityDesc  = "priority_desc"
    case createdAtDesc = "created_desc"
    case createdAtAsc  = "created_asc"
    case updatedAtDesc = "updated_desc"
    case dueDateAsc    = "due_asc"
    case titleAsc      = "title_asc"

    var displayName: String {
        switch self {
        case .priorityDesc:  "Priority (High → Low)"
        case .createdAtDesc: "Newest first"
        case .createdAtAsc:  "Oldest first"
        case .updatedAtDesc: "Recently updated"
        case .dueDateAsc:    "Due date (soonest)"
        case .titleAsc:      "Title (A → Z)"
        }
    }
}

/// Shared filter/sort state owned by RootSplitView, injected via .environment.
/// Never instantiate outside RootSplitView — children read via @Environment(FilterState.self).
@Observable
final class FilterState {
    var statuses: Set<IssueStatus> = []
    var priorities: Set<IssuePriority> = []
    var labelIDs: Set<UUID> = []
    var searchText: String = ""
    var sort: IssueSort = .createdAtDesc

    var isActive: Bool {
        !statuses.isEmpty || !priorities.isEmpty || !labelIDs.isEmpty || !searchText.isEmpty
    }

    func reset() {
        statuses = []
        priorities = []
        labelIDs = []
        searchText = ""
        sort = .createdAtDesc
    }

    func load(from view: SavedView) {
        statuses  = Set(view.statusesRaw.compactMap { IssueStatus(rawValue: $0) })
        priorities = Set(view.prioritiesRaw.compactMap { IssuePriority(rawValue: $0) })
        labelIDs  = Set(view.labelIDsRaw.compactMap { UUID(uuidString: $0) })
        searchText = view.searchText
        sort = IssueSort(rawValue: view.sortRaw) ?? .createdAtDesc
    }

    func encode(into view: SavedView) {
        view.statusesRaw   = statuses.map(\.rawValue)
        view.prioritiesRaw = priorities.map(\.rawValue)
        view.labelIDsRaw   = labelIDs.map(\.uuidString)
        view.searchText    = searchText
        view.sortRaw       = sort.rawValue
    }
}
