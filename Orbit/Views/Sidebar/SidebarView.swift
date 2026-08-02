import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(Selection.self) private var selection
    @Environment(AppActions.self) private var appActions
    @Environment(iCloudStatus.self) private var cloudStatus
    @Environment(\.modelContext) private var context
    @Query(sort: \Workspace.createdAt) private var workspaces: [Workspace]
    @State private var labelManagerWorkspace: Workspace?

    // Project edit/delete are hoisted to this stable view. An .alert or .sheet
    // attached to a row nested inside a DisclosureGroup does NOT present in
    // SwiftUI — so the project rename "did nothing". Presenting from here fixes it.
    @State private var projectToEdit: Project?
    @State private var projectToDelete: Project?

    var body: some View {
        @Bindable var sel = selection
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                BrandHeader()
                SidebarSearchButton(action: { appActions.showCommandPalette = true })
            }
            .padding(.top, 14)
            .padding(.horizontal, 10)
            .padding(.bottom, 14)

            List(selection: $sel.selectedProject) {
                SectionCaps(text: "Workspaces")
                    .padding(.horizontal, 6)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(workspaces) { workspace in
                    WorkspaceRow(
                        workspace: workspace,
                        onEditProject:   { projectToEdit = $0 },
                        onDeleteProject: { projectToDelete = $0 }
                    )
                }
                ForEach(workspaces) { workspace in
                    SavedViewsSection(workspace: workspace)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            SidebarFooter(status: cloudStatus.status)
        }
        .background(Nocturne.bgDeep)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Nocturne.divider).frame(width: 1)
        }
        .navigationTitle("Orbit")
        .sheet(item: $labelManagerWorkspace) { ws in
            LabelManagerView(workspace: ws)
        }
        // Project rename/description — presented from the stable SidebarView.
        .sheet(item: $projectToEdit) { project in
            ProjectEditSheet(project: project)
        }
        .confirmationDialog(
            "Delete project \"\(projectToDelete?.name ?? "")\" and all its issues?",
            isPresented: Binding(get: { projectToDelete != nil },
                                 set: { if !$0 { projectToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let project = projectToDelete { deleteProject(project) }
            }
            Button("Cancel", role: .cancel) { projectToDelete = nil }
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

    private func deleteProject(_ project: Project) {
        if selection.selectedProject?.persistentModelID == project.persistentModelID {
            selection.selectedProject = nil
        }
        context.delete(project)
        try? context.save()
        projectToDelete = nil
    }
}

// MARK: - Brand header

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            OrbitLogo(size: 24)
            Text("Orbit")
                .font(Nocturne.Font_.inter(15, .semibold))
                .foregroundStyle(Nocturne.text)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Search / jump button

private struct SidebarSearchButton: View {
    let action: () -> Void
    @State private var isHovered = false

    /// One-off from the spec, not a named Theme.swift token.
    private static let fieldBackground = Color(hex: "#191B28")
    private static let shortcutColor = Color(hex: "#595D6C")

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                Text("Buscar o saltar…")
                    .font(Nocturne.Font_.inter(12.5))
                Spacer(minLength: 6)
                Text("⌘K")
                    .font(Nocturne.Font_.inter(10.5))
                    .foregroundStyle(Self.shortcutColor)
            }
            .foregroundStyle(isHovered ? Nocturne.textMuted : Nocturne.textDim)
            .padding(.vertical, 6)
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity)
            .background(Self.fieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Nocturne.borderHover : Nocturne.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Custom disclosure style
// Full control over the caret glyph/color/rotation — the default DisclosureGroup
// chrome doesn't expose enough to hit the Nocturne spec (11pt caret, #595D6C).

private struct NocturneDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        configuration.isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Nocturne.Neutral.n700)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                        .frame(width: 11)
                }
                .buttonStyle(.plain)

                configuration.label
            }
            if configuration.isExpanded {
                configuration.content
            }
        }
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
    let onEditProject: (Project) -> Void
    let onDeleteProject: (Project) -> Void
    @Environment(\.modelContext) private var context
    @Environment(Selection.self) private var selection
    @State private var isExpanded = true
    @State private var editing: WorkspaceEdit? = nil
    @State private var editText = ""
    @State private var showColorPicker = false
    @State private var showDeleteConfirm = false
    @State private var isHovered = false

    var accentColor: Color {
        workspace.accentHex.isEmpty ? Nocturne.accent : Color(hex: workspace.accentHex)
    }

    /// Total issues across every project in this workspace — new sidebar datum.
    private var totalIssueCount: Int {
        workspace.unwrappedProjects.reduce(0) { $0 + ($1.issues?.count ?? 0) }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(workspace.unwrappedProjects) { project in
                ProjectRow(
                    project: project,
                    onEdit:   { onEditProject(project) },
                    onDelete: { onDeleteProject(project) }
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            if workspace.unwrappedProjects.isEmpty {
                Text("Sin proyectos")
                    .font(Nocturne.Font_.inter(11.5).italic())
                    .foregroundStyle(Nocturne.textFaint)
                    .padding(.leading, 24)
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(accentColor).frame(width: 7, height: 7)
                Text(workspace.name)
                    .font(Nocturne.Font_.inter(12.5, .medium))
                    .foregroundStyle(Nocturne.Neutral.n300)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Text("\(totalIssueCount)")
                    .font(Nocturne.Font_.meta)
                    .foregroundStyle(Nocturne.Neutral.n700)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 6).fill(isHovered ? Nocturne.surface : .clear))
            .onHover { isHovered = $0 }
        }
        .disclosureGroupStyle(NocturneDisclosureStyle())
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .contextMenu {
            Button("Rename Workspace") { editText = workspace.name; editing = .rename }
            Button(workspace.details.isEmpty ? "Add Description…" : "Edit Description…") {
                editText = workspace.details; editing = .description
            }
            Button("Change Color…") { showColorPicker = true }
            Divider()
            Button("Delete Workspace", role: .destructive) { showDeleteConfirm = true }
        }
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
// Pure presentation + intent. Rename/description/delete are delegated UP to
// SidebarView via closures, because alerts/sheets do not present from a row
// nested inside a DisclosureGroup.

private struct ProjectRow: View {
    @Bindable var project: Project
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(Selection.self) private var selection
    @State private var isHovered = false

    private var isSelected: Bool {
        selection.selectedProject?.persistentModelID == project.persistentModelID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Nocturne.accent : Nocturne.Neutral.n700)
                Text(project.name)
                    .font(Nocturne.Font_.inter(12.5))
                    .foregroundStyle(isSelected ? Nocturne.text : Nocturne.Neutral.n500)
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            if !project.details.isEmpty {
                Text(project.details)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Nocturne.textFaint)
                    .lineLimit(1)
                    .padding(.leading, 19)
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(alignment: .leading) {
            if isSelected {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Nocturne.accentSel)
                    Rectangle().fill(Nocturne.accent).frame(width: 2)
                }
            } else if isHovered {
                RoundedRectangle(cornerRadius: 6).fill(Nocturne.surface)
            }
        }
        .onHover { isHovered = $0 }
        .tag(project)
        .contextMenu {
            Button("Rename / Edit…") { onEdit() }
            Divider()
            Button("Delete Project", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - ProjectEditSheet
// Name + description editor for a project. Presented from SidebarView so it
// reliably appears (a sheet on the nested ProjectRow would not).

private struct ProjectEditSheet: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var details: String
    @FocusState private var nameFocused: Bool

    init(project: Project) {
        self.project = project
        _name = State(initialValue: project.name)
        _details = State(initialValue: project.details)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            Text("Edit Project").font(.headline)

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Name").font(.caption).foregroundStyle(.secondary)
                TextField("Project name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
            }

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Description").font(.caption).foregroundStyle(.secondary)
                TextField("Optional", text: $details, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { project.name = trimmed }
                    project.details = details.trimmingCharacters(in: .whitespaces)
                    try? context.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(DS.Space.xl)
        .frame(width: 360)
        .onAppear { nameFocused = true }
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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Workspace Color")
                    .font(Nocturne.Font_.inter(15, .medium))
                    .foregroundStyle(Nocturne.text)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Nocturne.border).frame(height: 1)
            }

            // Wraps to available width instead of a fixed 6-column grid.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                ForEach(palette, id: \.hex) { item in
                    WorkspaceColorSwatch(item: item, isSelected: accentHex == item.hex) {
                        accentHex = item.hex
                        onSave()
                        dismiss()
                    }
                }
            }
            .padding(18)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(OutlineAccentButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(width: 380)
        .background(Nocturne.surface)
        .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.sheet))
        .overlay(
            RoundedRectangle(cornerRadius: Nocturne.Radius.sheet)
                .stroke(Nocturne.Neutral.n800, lineWidth: 1)
        )
    }
}

private struct WorkspaceColorSwatch: View {
    let item: (name: String, hex: String)
    let isSelected: Bool
    let action: () -> Void

    /// "Check tint" from the spec — dark ink so it reads over both the
    /// vivid palette fills and the mostly-transparent Default swatch.
    private static let checkTint = Color(hex: "#161826")
    private static let defaultBorder = Color(hex: "#595D6C")

    var body: some View {
        Button(action: action) {
            ZStack {
                if item.hex.isEmpty {
                    Circle()
                        .strokeBorder(Self.defaultBorder, lineWidth: 1.5)
                        .frame(width: 38, height: 38)
                    Image(systemName: "nosign")
                        .font(.system(size: 14))
                        .foregroundStyle(Self.defaultBorder)
                } else {
                    Circle()
                        .fill(Color(hex: item.hex))
                        .frame(width: 38, height: 38)
                }
                if isSelected {
                    Circle()
                        .stroke(Nocturne.accent, lineWidth: 2)
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Self.checkTint)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .help(item.name)
    }
}

// MARK: - Footer

private struct SidebarFooter: View {
    let status: iCloudStatus.Status

    /// One-off from the spec, not a named Theme.swift token.
    private static let topBorder = Color(hex: "#1C1E2B")

    private var icon: String {
        switch status {
        case .available:   "checkmark.icloud"
        case .unavailable: "icloud.slash"
        case .unknown:      "icloud"
        }
    }

    private var label: String {
        switch status {
        case .available:               "iCloud sincronizado"
        case .unavailable(let reason): reason
        case .unknown:                 "Comprobando iCloud…"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11))
            Text(label).font(Nocturne.Font_.meta).lineLimit(1)
        }
        .foregroundStyle(Nocturne.Neutral.n700)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Self.topBorder).frame(height: 1)
        }
    }
}
