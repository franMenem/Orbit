import SwiftUI
import SwiftData

enum ContentViewMode: String {
    case list, board
}

struct ContentPaneView: View {
    @Environment(Selection.self) private var selection
    @Environment(\.modelContext) private var context
    @AppStorage("contentMode") private var mode: ContentViewMode = .list

    var body: some View {
        if let project = selection.selectedProject {
            Group {
                switch mode {
                case .list:  IssueListView(project: project)
                case .board: IssueBoardView(project: project)
                }
            }
            .navigationTitle(project.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { addIssue(to: project) } label: {
                        Image(systemName: "plus")
                    }
                    .help("New Issue")
                }
                ToolbarItem(placement: .secondaryAction) {
                    Picker("View", selection: $mode) {
                        SwiftUI.Label("List", systemImage: "list.bullet").tag(ContentViewMode.list)
                        SwiftUI.Label("Board", systemImage: "square.grid.2x2").tag(ContentViewMode.board)
                    }
                    .pickerStyle(.segmented)
                    .help("Toggle List / Board")
                }
            }
        } else {
            ContentUnavailableView(
                "No Project Selected",
                systemImage: "folder.badge.questionmark",
                description: Text("Choose a project from the sidebar or create one with the + button.")
            )
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
    }
}
