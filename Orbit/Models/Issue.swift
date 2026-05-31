import Foundation
import SwiftData

@Model
final class Issue {
    var id: UUID = UUID()
    var title: String = ""
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
