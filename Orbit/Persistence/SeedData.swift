import Foundation
import SwiftData

enum SeedData {
    /// Creates a default Workspace + Project on first launch and returns the default Project.
    /// Idempotent: if a workspace already exists, returns its first project.
    /// Must run on the same actor as the ModelContext (MainActor by default).
    static func ensureSeed(_ context: ModelContext) -> Project? {
        let workspaceCount = (try? context.fetchCount(FetchDescriptor<Workspace>())) ?? 0
        if workspaceCount == 0 {
            let workspace = Workspace(name: "Personal")
            let project = Project(name: "Inbox")
            project.workspace = workspace
            workspace.projects = [project]
            context.insert(workspace)
            context.insert(project)
            try? context.save()
            return project
        }
        let workspaces = (try? context.fetch(FetchDescriptor<Workspace>())) ?? []
        return workspaces.first?.unwrappedProjects.first
    }
}
