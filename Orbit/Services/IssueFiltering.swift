import Foundation

/// Pure, stateless filtering + sorting of issues. No SwiftData queries — all in-memory.
/// NEVER use #Predicate that traverses a to-many relationship (CloudKit crash rule).
enum IssueFiltering {

    static func apply(_ issues: [Issue], _ filter: FilterState) -> [Issue] {
        issues
            .filter { matches($0, filter) }
            .sorted(by: comparator(for: filter.sort))
    }

    // MARK: - Private

    private static func matches(_ issue: Issue, _ filter: FilterState) -> Bool {
        // Status: empty set = no constraint (OR within category)
        if !filter.statuses.isEmpty, !filter.statuses.contains(issue.status) { return false }
        // Priority: empty set = no constraint
        if !filter.priorities.isEmpty, !filter.priorities.contains(issue.priority) { return false }
        // Labels: at least ONE of the issue's labels must be in the filter set (OR)
        if !filter.labelIDs.isEmpty {
            let issueLabelIDs = Set(issue.unwrappedLabels.map(\.id))
            if issueLabelIDs.isDisjoint(with: filter.labelIDs) { return false }
        }
        // Search: case-insensitive, title OR details
        if !filter.searchText.isEmpty {
            let q = filter.searchText.lowercased()
            if !issue.title.lowercased().contains(q),
               !issue.details.lowercased().contains(q) { return false }
        }
        return true
    }

    private static func comparator(for sort: IssueSort) -> (Issue, Issue) -> Bool {
        switch sort {
        case .priorityDesc:  return { $0.priority > $1.priority }
        case .createdAtDesc: return { $0.createdAt > $1.createdAt }
        case .createdAtAsc:  return { $0.createdAt < $1.createdAt }
        case .updatedAtDesc: return { $0.updatedAt > $1.updatedAt }
        case .titleAsc:      return { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .dueDateAsc:
            return {
                switch ($0.dueDate, $1.dueDate) {
                case (.none, .none):         return false
                case (.none, .some):         return false  // nils last
                case (.some, .none):         return true
                case (.some(let a), .some(let b)): return a < b
                }
            }
        }
    }
}
