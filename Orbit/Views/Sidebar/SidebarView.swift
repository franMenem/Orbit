import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(Selection.self) private var selection
    @Environment(\.modelContext) private var context
    @Query(sort: \Workspace.createdAt) private var workspaces: [Workspace]
    @State private var labelManagerWorkspace: Workspace?

    var body: some View {
        @Bindable var sel = selection
        List(selection: $sel.selectedProject) {
            ForEach(workspaces) { workspace in
                WorkspaceRow(workspace: workspace)
            }

            ForEach(workspaces) { workspace in
                    SavedViewsSection(workspace: workspace)
                }
        }
        .navigationTitle("Orbit")
        .sheet(item: $labelManagerWorkspace) { ws in
            LabelManagerView(workspace: ws)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Workspace") { addWorkspace() }
                    if !workspaces.isEmpty {
                        Divider()
                        ForEach(workspaces) { workspace in
                            Button("New Project in \(workspace.name)") {
                                addProject(to: workspace)
                            }
                        }
                        Divider()
                        ForEach(workspaces) { workspace in
                            Button("Manage Labels in \(workspace.name)") {
                                labelManagerWorkspace = workspace
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func addWorkspace() {
        let workspace = Workspace(name: "New Workspace")
        context.insert(workspace)
        try? context.save()
    }

    private func addProject(to workspace: Workspace) {
        let project = Project(name: "New Project")
        project.workspace = workspace
        if workspace.projects == nil { workspace.projects = [] }
        workspace.projects?.append(project)
        context.insert(project)
        try? context.save()
        selection.selectedProject = project
    }
}

private struct WorkspaceRow: View {
    let workspace: Workspace
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(workspace.unwrappedProjects) { project in
                SwiftUI.Label(project.name, systemImage: "folder")
                    .tag(project)
            }
            if workspace.unwrappedProjects.isEmpty {
                Text("No projects")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        } label: {
            SwiftUI.Label(workspace.name, systemImage: "briefcase")
                .font(.headline)
        }
    }
}
