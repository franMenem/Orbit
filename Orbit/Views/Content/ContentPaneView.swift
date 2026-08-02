import SwiftUI
import SwiftData

enum ContentViewMode: String {
    case list, board
}

struct ContentPaneView: View {
    @Environment(Selection.self) private var selection
    @Environment(FilterState.self) private var filterState
    @Environment(AppActions.self) private var appActions
    @Environment(\.modelContext) private var context
    @AppStorage("contentMode") private var mode: ContentViewMode = .list
    @State private var newIssueProject: Project?

    var body: some View {
        Group {
            if let project = selection.selectedProject {
                ProjectContentView(project: project, mode: $mode,
                                   onNewIssue: { newIssueProject = project })
            } else if let savedView = selection.selectedSavedView {
                savedViewContent(savedView: savedView)
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Choose a project from the sidebar or create one with the + button.")
                )
            }
        }
        // "fondo de la columna Nocturne.bg" (README §3) — se aplica acá arriba
        // de todo para cubrir las tres ramas (proyecto, saved view, vacío).
        .background(Nocturne.bg)
        .onChange(of: appActions.createIssueSignal) { handleCreateIssue() }
        .onChange(of: appActions.pendingMode)       { handlePendingMode() }
        .sheet(item: $newIssueProject) { project in
            NewIssueSheet(project: project) { issue in
                selection.selectedIssue = issue
            }
        }
    }

    // MARK: - Saved View mode

    @ViewBuilder
    private func savedViewContent(savedView: SavedView) -> some View {
        let allIssues = savedView.workspace?.unwrappedProjects.flatMap(\.unwrappedIssues) ?? []
        let filtered  = IssueFiltering.apply(allIssues, filterState)
        VStack(spacing: 0) {
            FilterBar()
            IssueListView(issues: filtered)
        }
        .navigationTitle(savedView.name)
    }

    // MARK: - Signal handlers

    private func handleCreateIssue() {
        guard appActions.createIssueSignal else { return }
        appActions.createIssueSignal = false
        // Open the New Issue sheet for the active (or first) project.
        newIssueProject = selection.selectedProject ?? SeedData.ensureSeed(context)
    }

    private func handlePendingMode() {
        if let m = appActions.pendingMode { mode = m; appActions.pendingMode = nil }
    }
}
// MARK: - ProjectHeader
// Editable project name shown at the top of the content pane. Click the name
// to edit it inline — no need to find it in the sidebar.

private struct ProjectHeader: View {
    @Bindable var project: Project
    let onSave: () -> Void
    let onNewIssue: () -> Void
    @FocusState private var nameFocused: Bool

    private var issues: [Issue] { project.unwrappedIssues }
    private var total: Int { issues.count }
    private var inProgressCount: Int { issues.filter { $0.status == .inProgress }.count }

    /// "Cerrados" en el resumen agrupa Done + Cancelled (README §3: "1 cerrados").
    private var closedCount: Int {
        issues.filter { $0.status == .done || $0.status == .cancelled }.count
    }

    /// Criterio del anillo de progreso: numerador = solo `.done`. Cancelled
    /// cuenta como "cerrado" en el resumen de texto de arriba, pero no como
    /// avance real, así que no infla el arco (a diferencia de `closedCount`).
    private var doneFraction: Double {
        guard total > 0 else { return 0 }
        return Double(issues.filter { $0.status == .done }.count) / Double(total)
    }

    private var summaryText: String {
        "\(total) issues · \(inProgressCount) en progreso · \(closedCount) cerrados"
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(project.workspace?.name ?? "Workspace") / \(project.name)")
                    .font(Nocturne.Font_.meta)
                    .foregroundStyle(Nocturne.textDim)
                    .lineLimit(1)

                TextField("Project name", text: $project.name)
                    .textFieldStyle(.plain)
                    .font(Nocturne.Font_.projectTitle)
                    .foregroundStyle(Nocturne.text)
                    .focused($nameFocused)
                    .onChange(of: project.name) { onSave() }
                    .onSubmit { nameFocused = false }

                Text(summaryText)
                    .font(Nocturne.Font_.control)
                    .foregroundStyle(Nocturne.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: DS.Space.sm) {
                progressBadge
                newIssueButton
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Nocturne.divider).frame(height: 1)
        }
    }

    private var progressBadge: some View {
        let pct = Int((doneFraction * 100).rounded())
        return HStack(spacing: 8) {
            ProgressRing(fraction: doneFraction, size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(pct)%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Nocturne.text)
                Text("completado")
                    .font(Nocturne.Font_.chip)
                    .foregroundStyle(Nocturne.textDim)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Nocturne.border, lineWidth: 1)
        )
    }

    private var newIssueButton: some View {
        // OutlineAccentButtonStyle ya aplica radio 8, padding 7/12 y
        // texto 12.5pt/500 — coincide exacto con el spec, sin overrides.
        Button(action: onNewIssue) {
            SwiftUI.Label("Nuevo issue", systemImage: "plus")
        }
        .buttonStyle(OutlineAccentButtonStyle())
    }
}

// MARK: - ProjectContentView
// Separate struct so we can use @Bindable for inline title editing.
// .navigationTitle($project.name) makes the title editable on double-click.

private struct ProjectContentView: View {
    @Bindable var project: Project
    @Binding var mode: ContentViewMode
    let onNewIssue: () -> Void
    @Environment(FilterState.self) private var filterState
    @Environment(\.modelContext) private var context

    var body: some View {
        let filtered = IssueFiltering.apply(project.unwrappedIssues, filterState)
        VStack(spacing: 0) {
            ProjectHeader(project: project, onSave: { try? context.save() }, onNewIssue: onNewIssue)
            FilterBar()
            switch mode {
            case .list:  IssueListView(issues: filtered)
            case .board: IssueBoardView(issues: filtered)
            }
        }
        // Window title bar shows the WORKSPACE for context; the project name
        // lives ONLY in the editable ProjectHeader below — never shown twice.
        .navigationTitle(project.workspace?.name ?? "Orbit")
        .onChange(of: project.name) { try? context.save() }
        .toolbar {
            // El botón "+" primario se retiró del toolbar: "Nuevo issue" ahora
            // vive en ProjectHeader (spec §3), evita el ícono duplicado.
            ToolbarItem(placement: .secondaryAction) {
                Picker("View", selection: $mode) {
                    SwiftUI.Label("List",  systemImage: "list.bullet").tag(ContentViewMode.list)
                    SwiftUI.Label("Board", systemImage: "square.grid.2x2").tag(ContentViewMode.board)
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
