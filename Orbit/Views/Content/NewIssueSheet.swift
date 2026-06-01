import SwiftUI
import SwiftData

/// Modal for creating an issue. Nothing is written to the store until the
/// user presses Create (or Enter). Cancel discards without creating anything —
/// no more empty "Untitled" rows left lying around.
struct NewIssueSheet: View {
    let project: Project
    let onCreate: (Issue) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var details = ""
    @State private var status: IssueStatus = .backlog
    @State private var priority: IssuePriority = .none
    @FocusState private var titleFocused: Bool

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            Text("New Issue")
                .font(.headline)
            Text("in \(project.name)")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Title").font(.caption).foregroundStyle(.secondary)
                TextField("What needs to be done?", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .focused($titleFocused)
                    .onSubmit { if canCreate { create() } }
            }

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text("Description").font(.caption).foregroundStyle(.secondary)
                TextField("Optional", text: $details, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
            }

            HStack(spacing: DS.Space.lg) {
                Picker(selection: $status) {
                    ForEach(IssueStatus.allCases, id: \.self) { s in
                        SwiftUI.Label(s.displayName, systemImage: s.glyph).tag(s)
                    }
                } label: {
                    Text("Status")
                }
                Picker(selection: $priority) {
                    ForEach(IssuePriority.allCases, id: \.self) { p in
                        SwiftUI.Label(p.displayName, systemImage: p.symbolName).tag(p)
                    }
                } label: {
                    Text("Priority")
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") { create() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canCreate)
            }
        }
        .padding(DS.Space.xl)
        .frame(width: 420)
        .onAppear { titleFocused = true }
    }

    private func create() {
        let issue = Issue(title: title.trimmingCharacters(in: .whitespaces))
        issue.details  = details.trimmingCharacters(in: .whitespaces)
        issue.status   = status
        issue.priority = priority
        issue.project  = project
        if project.issues == nil { project.issues = [] }
        project.issues?.append(issue)
        context.insert(issue)
        try? context.save()
        onCreate(issue)
        dismiss()
    }
}
