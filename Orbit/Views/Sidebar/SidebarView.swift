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

// MARK: - WorkspaceRow

private struct WorkspaceRow: View {
    @Bindable var workspace: Workspace
    @Environment(\.modelContext) private var context
    @Environment(Selection.self) private var selection
    @State private var isExpanded = true
    @State private var showRename = false
    @State private var editName = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(workspace.unwrappedProjects) { project in
                ProjectRow(project: project)
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
        .contextMenu {
            Button("Rename Workspace") {
                editName = workspace.name
                showRename = true
            }
            Divider()
            Button("Delete Workspace", role: .destructive) {
                showDeleteConfirm = true
            }
        }
        .alert("Rename Workspace", isPresented: $showRename) {
            TextField("Name", text: $editName)
            Button("Rename") {
                workspace.name = editName.trimmingCharacters(in: .whitespaces).isEmpty
                    ? workspace.name : editName
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete workspace \"\(workspace.name)\" and all its projects and issues?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if workspace.unwrappedProjects.contains(where: {
                    $0.persistentModelID == selection.selectedProject?.persistentModelID
                }) {
                    selection.selectedProject = nil
                }
                context.delete(workspace)
                try? context.save()
            }
        }
    }
}

// MARK: - ProjectRow

private struct ProjectRow: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context
    @Environment(Selection.self) private var selection
    @State private var showRename = false
    @State private var editName = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        SwiftUI.Label(project.name, systemImage: "folder")
            .tag(project)
            .contextMenu {
                Button("Rename Project") {
                    editName = project.name
                    showRename = true
                }
                Divider()
                Button("Delete Project", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
            .alert("Rename Project", isPresented: $showRename) {
                TextField("Name", text: $editName)
                Button("Rename") {
                    project.name = editName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? project.name : editName
                    try? context.save()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Delete project \"\(project.name)\" and all its issues?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if selection.selectedProject?.persistentModelID == project.persistentModelID {
                        selection.selectedProject = nil
                    }
                    context.delete(project)
                    try? context.save()
                }
            }
    }
}
