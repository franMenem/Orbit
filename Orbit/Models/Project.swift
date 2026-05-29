import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var name: String = "New Project"
    var createdAt: Date = Date.now

    var workspace: Workspace? = nil

    @Relationship(deleteRule: .cascade, inverse: \Issue.project)
    var issues: [Issue]? = []

    var unwrappedIssues: [Issue] {
        issues ?? []
    }

    init(name: String = "New Project") {
        self.name = name
    }
}
