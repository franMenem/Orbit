import SwiftUI
import SwiftData

struct IssueDetailView: View {
    @Environment(Selection.self) private var selection

    var body: some View {
        if let issue = selection.selectedIssue {
            IssueEditorView(issue: issue)
                .id(issue.persistentModelID)
        } else {
            ContentUnavailableView(
                "No Issue Selected",
                systemImage: "doc.text",
                description: Text("Select an issue from the list or create one with the + button.")
            )
        }
    }
}

private struct IssueEditorView: View {
    @Bindable var issue: Issue
    @Environment(\.modelContext) private var context
    @State private var hasDueDate: Bool

    init(issue: Issue) {
        self.issue = issue
        _hasDueDate = State(initialValue: issue.dueDate != nil)
    }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $issue.title)
                    .font(.title3.weight(.semibold))
                    .onChange(of: issue.title) { save() }
            }

            Section("Details") {
                TextEditor(text: $issue.details)
                    .frame(minHeight: 80)
                    .onChange(of: issue.details) { save() }
            }

            Section("Properties") {
                Picker("Status", selection: $issue.status) {
                    ForEach(IssueStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .onChange(of: issue.status) { save() }

                Picker("Priority", selection: $issue.priority) {
                    ForEach(IssuePriority.allCases, id: \.self) { priority in
                        SwiftUI.Label(priority.displayName, systemImage: priority.symbolName)
                            .tag(priority)
                    }
                }
                .onChange(of: issue.priority) { save() }
            }

            Section("Due Date") {
                Toggle("Has due date", isOn: $hasDueDate)
                    .onChange(of: hasDueDate) {
                        issue.dueDate = hasDueDate ? (issue.dueDate ?? Date.now) : nil
                        save()
                    }
                if hasDueDate {
                    DatePicker(
                        "Due date",
                        selection: Binding(
                            get: { issue.dueDate ?? Date.now },
                            set: { issue.dueDate = $0; save() }
                        ),
                        displayedComponents: .date
                    )
                }
            }

            // TODO(Phase 3): Labels chip row here

            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Created \(issue.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("Updated \(issue.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(issue.title.isEmpty ? "Untitled Issue" : issue.title)
    }

    private func save() {
        issue.updatedAt = .now
        try? context.save()
    }
}
