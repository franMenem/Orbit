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
                projectView(project: project)
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

    // MARK: - Project mode

    @ViewBuilder
    private func projectView(project: Project) -> some View {
        let filtered = IssueFiltering.apply(project.unwrappedIssues, filterState)
        VStack(spacing: 0) {
            FilterBar()
            switch mode {
            case .list:  IssueListView(issues: filtered)
            case .board: IssueBoardView(issues: filtered)
            }
        }
        .navigationTitle(project.name)
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

    // MARK: - Saved View mode (workspace-wide)

    @ViewBuilder
    private func savedViewContent(savedView: SavedView) -> some View {
        let allIssues = savedView.workspace?.unwrappedProjects.flatMap(\.unwrappedIssues) ?? []
        let filtered = IssueFiltering.apply(allIssues, filterState)
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
        if let m = appActions.pendingMode {
            mode = m
            appActions.pendingMode = nil
        }
    }

    // MARK: - Helpers

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
