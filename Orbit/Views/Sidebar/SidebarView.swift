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
                } label: { Image(systemName: "plus") }
            }
        }
        .onAppear {
            let firstProject = SeedData.ensureSeed(context)
            if selection.selectedProject == nil {
                selection.selectedProject = firstProject
            }
        }
    }

    private func addWorkspace() {
        let ws = Workspace(name: "New Workspace")
        context.insert(ws)
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
// Bug fix: SwiftUI silently ignores all but the LAST .alert modifier on a view.
// Solution: one enum drives a single .alert that handles every edit case.

private enum WorkspaceEdit: Identifiable {
    case rename, description
    var id: Self { self }
    var title: String { self == .rename ? "Rename Workspace" : "Workspace Description" }
    var placeholder: String { self == .rename ? "Name" : "Short description (optional)" }
}

private struct WorkspaceRow: View {
    @Bindable var workspace: Workspace
    @Environment(\.modelContext) private var context
    @Environment(Selection.self) private var selection
    @State private var isExpanded    = true
    @State private var editing: WorkspaceEdit? = nil
    @State private var editText      = ""
    @State private var showColorPicker   = false
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
                Circle().fill(accentColor).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(workspace.name).font(.headline)
                    if !workspace.details.isEmpty {
                        Text(workspace.details)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
        .contextMenu {
            Button("Rename Workspace") {
                editText = workspace.name; editing = .rename
            }
            Button(workspace.details.isEmpty ? "Add Description…" : "Edit Description…") {
                editText = workspace.details; editing = .description
            }
            Button("Change Color…") { showColorPicker = true }
            Divider()
            Button("Delete Workspace", role: .destructive) { showDeleteConfirm = true }
        }
        // ── Single alert — driven by `editing` enum ───────────────────────
        .alert(
            editing?.title ?? "",
            isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
        ) {
            TextField(editing?.placeholder ?? "", text: $editText)
            Button("Save") {
                let trimmed = editText.trimmingCharacters(in: .whitespaces)
                switch editing {
                case .rename:      if !trimmed.isEmpty { workspace.name = trimmed }
                case .description: workspace.details = trimmed
                case nil: break
                }
                editing = nil
                try? context.save()
            }
            Button("Cancel", role: .cancel) { editing = nil }
        }
        .sheet(isPresented: $showColorPicker) {
            WorkspaceColorPicker(accentHex: $workspace.accentHex) { try? context.save() }
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

private enum ProjectEdit: Identifiable {
    case rename, description
    var id: Self { self }
    var title: String { self == .rename ? "Rename Project" : "Project Description" }
    var placeholder: String { self == .rename ? "Name" : "Short description (optional)" }
}

private struct ProjectRow: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context
    @Environment(Selection.self) private var selection
    @State private var editing: ProjectEdit? = nil
    @State private var editText      = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            SwiftUI.Label(project.name, systemImage: "folder")
            if !project.details.isEmpty {
                Text(project.details)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).padding(.leading, 20)
            }
        }
        .tag(project)
        .contextMenu {
            Button("Rename Project") {
                editText = project.name; editing = .rename
            }
            Button(project.details.isEmpty ? "Add Description…" : "Edit Description…") {
                editText = project.details; editing = .description
            }
            Divider()
            Button("Delete Project", role: .destructive) { showDeleteConfirm = true }
        }
        // ── Single alert ──────────────────────────────────────────────────
        .alert(
            editing?.title ?? "",
            isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
        ) {
            TextField(editing?.placeholder ?? "", text: $editText)
            Button("Save") {
                let trimmed = editText.trimmingCharacters(in: .whitespaces)
                switch editing {
                case .rename:      if !trimmed.isEmpty { project.name = trimmed }
                case .description: project.details = trimmed
                case nil: break
                }
                editing = nil
                try? context.save()
            }
            Button("Cancel", role: .cancel) { editing = nil }
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
        ("Blue",    "#5E9EFF"), ("Purple", "#A865C9"), ("Pink",   "#FF7CA3"),
        ("Red",     "#E8415B"), ("Orange", "#F5A623"), ("Yellow", "#FFC940"),
        ("Green",   "#56CF8F"), ("Teal",   "#4DBCB0"), ("Cyan",   "#57C4E8"),
        ("Gray",    "#6E7278"),
    ]

    let columns = Array(repeating: GridItem(.fixed(44), spacing: 8), count: 6)

    var body: some View {
        VStack(spacing: 16) {
            Text("Workspace Color").font(.headline)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(palette, id: \.hex) { item in
                    Button {
                        accentHex = item.hex; onSave(); dismiss()
                    } label: {
                        ZStack {
                            if item.hex.isEmpty {
                                Circle().strokeBorder(.secondary, lineWidth: 1.5)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "circle.slash")
                                    .foregroundStyle(.secondary).font(.caption)
                            } else {
                                Circle().fill(Color(hex: item.hex))
                                    .frame(width: 36, height: 36)
                            }
                            if accentHex == item.hex {
                                Image(systemName: "checkmark").font(.caption.bold())
                                    .foregroundStyle(item.hex.isEmpty ? Color.primary : Color.white)
                            }
                        }
                    }
                    .buttonStyle(.plain).help(item.name)
                }
            }
            Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding(20).frame(width: 320)
    }
}
