import Foundation
import SwiftData

@Model
final class Workspace {
    var id: UUID = UUID()
    var name: String = "New Workspace"
    var details: String = ""
    var accentHex: String = ""          // "" means default accent
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Project.workspace)
    var projects: [Project]? = []

    @Relationship(deleteRule: .cascade, inverse: \Label.workspace)
    var labels: [Label]? = []

    @Relationship(deleteRule: .cascade, inverse: \SavedView.workspace)
    var savedViews: [SavedView]? = []

    var unwrappedProjects: [Project] {
        (projects ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var unwrappedLabels: [Label] {
        (labels ?? []).sorted { $0.name < $1.name }
    }

    var unwrappedSavedViews: [SavedView] {
        (savedViews ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    init(name: String = "New Workspace") {
        self.name = name
    }
}
