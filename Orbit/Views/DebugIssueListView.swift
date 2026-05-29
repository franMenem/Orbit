import SwiftUI
import SwiftData

struct DebugIssueListView: View {
    @Query(sort: \Issue.createdAt, order: .reverse) private var issues: [Issue]
    @Environment(\.modelContext) private var context
    @State private var defaultProject: Project?

    var body: some View {
        NavigationStack {
            List {
                ForEach(issues) { issue in
                    VStack(alignment: .leading) {
                        Text(issue.title.isEmpty ? "(untitled)" : issue.title)
                        Text("\(issue.status.displayName) · \(issue.priority.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteIssues)
            }
            .navigationTitle("Orbit — Debug")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Sample Issue") { addIssue() }
                        .disabled(defaultProject == nil)
                }
            }
        }
        .task {
            defaultProject = SeedData.ensureSeed(context)
        }
    }

    private func addIssue() {
        guard let project = defaultProject else { return }
        let issue = Issue(title: "Issue \(issues.count + 1)")
        issue.project = project
        if project.issues == nil { project.issues = [] }
        project.issues?.append(issue)
        context.insert(issue)
        try? context.save()
    }

    private func deleteIssues(_ offsets: IndexSet) {
        for index in offsets { context.delete(issues[index]) }
        try? context.save()
    }
}
