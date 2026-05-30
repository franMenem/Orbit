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
        .onAppear {
            // Seed on first launch; auto-select the first project if nothing is chosen.
            let firstProject = SeedData.ensureSeed(context)
            if selection.selectedProject == nil {
                selection.selectedProject = firstProject
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
    @State private var showDescription = false
    @State private var editDescription = ""
    @State private var showColorPicker = false
    @State private var showDeleteConfirm = false

    var accentColor: Color {
        workspace.accentHex.isEmpty ? .accentColor : Color(hex: workspace.accentHex)
    }

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
            HStack(spacing: 6) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(workspace.name).font(.headline)
                    if !workspace.details.isEmpty {
                        Text(workspace.details)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .contextMenu {
            Button("Rename Workspace") {
                editName = workspace.name; showRename = true
            }
            Button(workspace.details.isEmpty ? "Add Description…" : "Edit Description…") {
                editDescription = workspace.details; showDescription = true
            }
            Button("Change Color…") { showColorPicker = true }
            Divider()
            Button("Delete Workspace", role: .destructive) { showDeleteConfirm = true }
        }
        .alert("Rename Workspace", isPresented: $showRename) {
            TextField("Name", text: $editName)
            Button("Rename") {
                let t = editName.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { workspace.name = t }
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Workspace Description", isPresented: $showDescription) {
            TextField("Short description (optional)", text: $editDescription)
            Button("Save") {
                workspace.details = editDescription.trimmingCharacters(in: .whitespaces)
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showColorPicker) {
            WorkspaceColorPicker(accentHex: $workspace.accentHex, onSave: { try? context.save() })
        }
        .confirmationDialog(
            "Delete workspace \"\(workspace.name)\" and all its projects and issues?",
            isPresented: $showDeleteConfirm, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if workspace.unwrappedProjects.contains(where: {
                    $0.persistentModelID == selection.selectedProject?.persistentModelID
                }) { selection.selectedProject = nil }
                context.delete(workspace); try? context.save()
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
    @State private var showDescription = false
    @State private var editDescription = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            SwiftUI.Label(project.name, systemImage: "folder")
            if !project.details.isEmpty {
                Text(project.details)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 20)
            }
        }
        .tag(project)
        .contextMenu {
            Button("Rename Project") { editName = project.name; showRename = true }
            Button(project.details.isEmpty ? "Add Description…" : "Edit Description…") {
                editDescription = project.details; showDescription = true
            }
            Divider()
            Button("Delete Project", role: .destructive) { showDeleteConfirm = true }
        }
        .alert("Rename Project", isPresented: $showRename) {
            TextField("Name", text: $editName)
            Button("Rename") {
                let t = editName.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { project.name = t }
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Project Description", isPresented: $showDescription) {
            TextField("Short description (optional)", text: $editDescription)
            Button("Save") {
                project.details = editDescription.trimmingCharacters(in: .whitespaces)
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete project \"\(project.name)\" and all its issues?",
            isPresented: $showDeleteConfirm, titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if selection.selectedProject?.persistentModelID == project.persistentModelID {
                    selection.selectedProject = nil
                }
                context.delete(project); try? context.save()
            }
        }
    }
}

// MARK: - WorkspaceColorPicker

private struct WorkspaceColorPicker: View {
    @Binding var accentHex: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let palette: [(name: String, hex: String)] = [
        ("Default", ""),
        ("Blue",    "#5E9EFF"),
        ("Purple",  "#A865C9"),
        ("Pink",    "#FF7CA3"),
        ("Red",     "#E8415B"),
        ("Orange",  "#F5A623"),
        ("Yellow",  "#FFC940"),
        ("Green",   "#56CF8F"),
        ("Teal",    "#4DBCB0"),
        ("Cyan",    "#57C4E8"),
        ("Gray",    "#6E7278"),
    ]

    let columns = Array(repeating: GridItem(.fixed(44), spacing: 8), count: 6)

    var body: some View {
        VStack(spacing: 16) {
            Text("Workspace Color")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(palette, id: \.hex) { item in
                    Button {
                        accentHex = item.hex
                        onSave()
                        dismiss()
                    } label: {
                        ZStack {
                            if item.hex.isEmpty {
                                Circle()
                                    .strokeBorder(.secondary, lineWidth: 1.5)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "circle.slash")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            } else {
                                Circle()
                                    .fill(Color(hex: item.hex))
                                    .frame(width: 36, height: 36)
                            }
                            if accentHex == item.hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(item.hex.isEmpty ? Color.primary : Color.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(item.name)
                }
            }
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 320)
    }
}
