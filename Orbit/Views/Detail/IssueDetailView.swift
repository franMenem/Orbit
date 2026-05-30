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
    @Environment(AppActions.self) private var appActions
    @State private var hasDueDate: Bool
    @State private var copyConfirmation: String? = nil
    @FocusState private var isTitleFocused: Bool

    init(issue: Issue) {
        self.issue = issue
        _hasDueDate = State(initialValue: issue.dueDate != nil)
    }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 8) {
                    TextField("Title", text: $issue.title)
                        .font(.title3.weight(.semibold))
                        .focused($isTitleFocused)
                        .onChange(of: issue.title) { save() }
                        .textFieldStyle(.plain)

                    Menu {
                        Button {
                            let r = ClipboardService.copyIssueForAI(issue)
                            showConfirmation(r.summary)
                        } label: {
                            SwiftUI.Label("Copy for AI (text + files)", systemImage: "sparkles")
                        }
                        Button {
                            _ = ClipboardService.copyIssueAsMarkdown(issue)
                            showConfirmation("Copied markdown")
                        } label: {
                            SwiftUI.Label("Copy as Markdown only", systemImage: "doc.plaintext")
                        }
                    } label: {
                        SwiftUI.Label("Copy for AI", systemImage: "sparkles")
                            .font(.caption.weight(.medium))
                    } primaryAction: {
                        let r = ClipboardService.copyIssueForAI(issue)
                        showConfirmation(r.summary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.visible)
                    .fixedSize()
                    .help("Copy this issue to the clipboard (⇧⌘C)")
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                }
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

            Section("Labels") {
                LabelsRow(issue: issue)
            }

            Section("Attachments") {
                AttachmentsView(issue: issue)
            }

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
        .overlay(alignment: .top) {
            if let msg = copyConfirmation {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg).font(.caption.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.15), radius: 6, y: 2)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: appActions.focusNewIssueTitle) {
            if appActions.focusNewIssueTitle {
                isTitleFocused = true
                appActions.focusNewIssueTitle = false
            }
        }
    }

    private func save() {
        issue.updatedAt = .now
        try? context.save()
    }

    private func showConfirmation(_ message: String) {
        withAnimation(.spring(duration: 0.25)) { copyConfirmation = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.3)) { copyConfirmation = nil }
        }
    }
}

private struct LabelsRow: View {
    @Bindable var issue: Issue
    @State private var showPicker = false

    var workspace: Workspace? { issue.project?.workspace }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 4) {
                ForEach(issue.unwrappedLabels) { label in
                    LabelChip(name: label.name, colorHex: label.colorHex) {
                        // remove on ×
                        issue.labels?.removeAll { $0.persistentModelID == label.persistentModelID }
                        label.issues?.removeAll { $0.persistentModelID == issue.persistentModelID }
                    }
                }
                Button {
                    showPicker = true
                } label: {
                    SwiftUI.Label("Add", systemImage: "plus")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
        }
        .sheet(isPresented: $showPicker) {
            if let ws = workspace {
                LabelPickerView(issue: issue, workspace: ws)
            }
        }
    }
}

/// Simple flow layout for chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}
