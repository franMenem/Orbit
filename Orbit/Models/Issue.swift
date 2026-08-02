import Foundation
import SwiftData

@Model
final class Issue {
    var id: UUID = UUID()
    var title: String = ""
    /// Short human-readable identifier, e.g. "FSL-3". Empty for issues created
    /// before this field existed until the backfill in `SeedData` runs; the UI
    /// should show "—" when empty rather than assume it's always populated.
    var code: String = ""
    var details: String = ""
    var solution: String = ""
    var status: IssueStatus = IssueStatus.backlog
    var priority: IssuePriority = IssuePriority.none
    var isPinned: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var dueDate: Date? = nil

    var project: Project? = nil

    // Sole declaration of the Issue↔Label inverse. Label.issues has no @Relationship macro.
    @Relationship(deleteRule: .nullify, inverse: \Label.issues)
    var labels: [Label]? = []

    @Relationship(deleteRule: .cascade, inverse: \Attachment.issue)
    var attachments: [Attachment]? = []

    var unwrappedLabels: [Label] {
        (labels ?? []).sorted { $0.name < $1.name }
    }

    init(title: String = "") {
        self.title = title
    }
}

extension Issue {
    /// Generates the next sequential code for an issue about to be created in
    /// `project`, e.g. "FSL-3". Prefix = first 3 alphanumeric characters of
    /// the project name, uppercased (falls back to "ISS" if the name has
    /// none). Number = highest existing sequence number among the project's
    /// issues + 1, so it keeps counting even if the project was renamed and
    /// its prefix changed along the way.
    static func makeCode(for project: Project) -> String {
        let letters = project.name.uppercased().filter { $0.isLetter || $0.isNumber }
        let prefix = letters.isEmpty ? "ISS" : String(letters.prefix(3))

        let maxN = project.unwrappedIssues
            .compactMap { $0.code.split(separator: "-").last }
            .compactMap { Int($0) }
            .max() ?? 0

        return "\(prefix)-\(maxN + 1)"
    }
}
