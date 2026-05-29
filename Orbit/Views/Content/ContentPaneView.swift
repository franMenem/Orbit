import SwiftUI
import SwiftData

enum ContentViewMode: String {
    case list, board
}

struct ContentPaneView: View {
    @Environment(Selection.self) private var selection
    @Environment(FilterState.self) private var filterState
    @Environment(\.modelContext) private var context
    @AppStorage("contentMode") private var mode: ContentViewMode = .list

    var body: some View {
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

    // MARK: - Project mode (list or board)

    @ViewBuilder
    private func projectView(project: Project) -> some View {
        let filtered = IssueFiltering.apply(project.unwrappedIssues, filterState)
        VStack(spacing: 0) {
            FilterBar()
            contentBody(issues: filtered, project: project)
        }
        .navigationTitle(project.name)
        .toolbar { projectToolbar(project: project) }
    }

    @ViewBuilder
    private func contentBody(issues: [Issue], project: Project) -> some View {
        switch mode {
        case .list:  IssueListView(issues: issues)
        case .board: IssueBoardView(issues: issues)
        }
    }

    @ToolbarContentBuilder
    private func projectToolbar(project: Project) -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { addIssue(to: project) } label: {
                Image(systemName: "plus")
            }
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

    // MARK: - Saved View mode (workspace-wide)

    @ViewBuilder
    private func savedViewContent(savedView: SavedView) -> some View {
        let allIssues = savedView.workspace?.unwrappedProjects
            .flatMap(\.unwrappedIssues) ?? []
        let filtered = IssueFiltering.apply(allIssues, filterState)
        VStack(spacing: 0) {
            FilterBar()
            IssueListView(issues: filtered)
        }
        .navigationTitle(savedView.name)
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
    }
}
