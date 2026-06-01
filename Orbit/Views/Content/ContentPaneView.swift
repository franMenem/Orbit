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

    var body: some View {
        Group {
            if let project = selection.selectedProject {
                ProjectContentView(project: project, mode: $mode)
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
        .onChange(of: appActions.createIssueSignal) { handleCreateIssue() }
        .onChange(of: appActions.pendingMode)       { handlePendingMode() }
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
        let project = selection.selectedProject ?? SeedData.ensureSeed(context)
        if let project { addIssue(to: project) }
    }

    private func handlePendingMode() {
        if let m = appActions.pendingMode { mode = m; appActions.pendingMode = nil }
    }

    private func addIssue(to project: Project) {
        let issue = Issue(title: "")
        issue.project = project
        if project.issues == nil { project.issues = [] }
        project.issues?.append(issue)
        context.insert(issue)
        try? context.save()
        selection.selectedIssue = issue
        appActions.focusNewIssueTitle = true
    }
}
// MARK: - ProjectHeader
// Editable project name shown at the top of the content pane. Click the name
// to edit it inline — no need to find it in the sidebar.

private struct ProjectHeader: View {
    @Bindable var project: Project
    let onSave: () -> Void
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            TextField("Project name", text: $project.name)
                .textFieldStyle(.plain)
                .font(.title2.weight(.bold))
                .focused($nameFocused)
                .onChange(of: project.name) { onSave() }
                .onSubmit { nameFocused = false }

            if !project.details.isEmpty {
                Text(project.details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.top, DS.Space.lg)
        .padding(.bottom, DS.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}

// MARK: - ProjectContentView
// Separate struct so we can use @Bindable for inline title editing.
// .navigationTitle($project.name) makes the title editable on double-click.

private struct ProjectContentView: View {
    @Bindable var project: Project
    @Binding var mode: ContentViewMode
    @Environment(Selection.self) private var selection
    @Environment(FilterState.self) private var filterState
    @Environment(AppActions.self) private var appActions
    @Environment(\.modelContext) private var context

    var body: some View {
        let filtered = IssueFiltering.apply(project.unwrappedIssues, filterState)
        VStack(spacing: 0) {
            ProjectHeader(project: project, onSave: { try? context.save() })
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
            ToolbarItem(placement: .primaryAction) {
                Button { addIssue(to: project) } label: { Image(systemName: "plus") }
                    .help("New Issue (⌘N)")
            }
            ToolbarItem(placement: .secondaryAction) {
                Picker("View", selection: $mode) {
                    SwiftUI.Label("List",  systemImage: "list.bullet").tag(ContentViewMode.list)
                    SwiftUI.Label("Board", systemImage: "square.grid.2x2").tag(ContentViewMode.board)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func addIssue(to project: Project) {
        let issue = Issue(title: "")
        issue.project = project
        if project.issues == nil { project.issues = [] }
        project.issues?.append(issue)
        context.insert(issue)
        try? context.save()
        selection.selectedIssue = issue
        appActions.focusNewIssueTitle = true
    }
}
