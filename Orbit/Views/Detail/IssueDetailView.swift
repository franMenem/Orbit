import SwiftUI
import SwiftData

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueDetailView (root)
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueEditorView (composer)
// Responsibility: arrange sections + own the copy-confirmation toast state.
// All editing logic is delegated to focused sub-views.
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueEditorView: View {
    @Bindable var issue: Issue
    @Environment(\.modelContext) private var context
    @Environment(AppActions.self) private var appActions
    @State private var copyConfirmation: String? = nil
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            IssueTitleHeader(
                issue: issue,
                isTitleFocused: $isTitleFocused,
                onSave: save,
                onCopyDone: showConfirmation
            )
            IssueDetailsSection(issue: issue, onSave: save)
            IssueSolutionSection(issue: issue, onSave: save)
            IssuePropertiesSection(issue: issue, onSave: save)
            IssueDueDateSection(issue: issue, onSave: save)

            Section("Labels") {
                LabelsRow(issue: issue)
            }
            Section("Attachments") {
                AttachmentsView(issue: issue)
            }

            IssueMetadataFooter(issue: issue)
        }
        .formStyle(.grouped)
        .navigationTitle(issue.title.isEmpty ? "Untitled Issue" : issue.title)
        .overlay(alignment: .top) {
            CopyConfirmationPill(message: copyConfirmation)
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueTitleHeader
// Responsibility: title field + Copy-for-AI menu trigger.
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueTitleHeader: View {
    @Bindable var issue: Issue
    @FocusState.Binding var isTitleFocused: Bool
    let onSave: () -> Void
    let onCopyDone: (String) -> Void

    var body: some View {
        Section {
            HStack(alignment: .center, spacing: 8) {
                TextField("Title", text: $issue.title)
                    .font(.title3.weight(.semibold))
                    .focused($isTitleFocused)
                    .onChange(of: issue.title) { onSave() }
                    .textFieldStyle(.plain)

                CopyForAIMenu(issue: issue, onCopyDone: onCopyDone)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CopyForAIMenu
// Responsibility: the split-button that triggers the two clipboard modes.
// ─────────────────────────────────────────────────────────────────────────────

private struct CopyForAIMenu: View {
    let issue: Issue
    let onCopyDone: (String) -> Void

    var body: some View {
        Menu {
            Button { copyForAI() } label: {
                SwiftUI.Label("Copy for AI (text + files)", systemImage: "sparkles")
            }
            Button { copyMarkdown() } label: {
                SwiftUI.Label("Copy as Markdown only", systemImage: "doc.plaintext")
            }
        } label: {
            SwiftUI.Label("Copy for AI", systemImage: "sparkles")
                .font(.caption.weight(.medium))
        } primaryAction: {
            copyForAI()
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize()
        .help("Copy this issue to the clipboard (⇧⌘C)")
        .keyboardShortcut("c", modifiers: [.command, .shift])
    }

    private func copyForAI() {
        let result = ClipboardService.copyIssueForAI(issue)
        onCopyDone(result.summary)
    }

    private func copyMarkdown() {
        _ = ClipboardService.copyIssueAsMarkdown(issue)
        onCopyDone("Copied markdown")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueDetailsSection
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueDetailsSection: View {
    @Bindable var issue: Issue
    let onSave: () -> Void

    var body: some View {
        Section("Details") {
            RichTextField(
                text: $issue.details,
                placeholder: "Describe the issue… (markdown supported)",
                onCommit: onSave
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueSolutionSection
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueSolutionSection: View {
    @Bindable var issue: Issue
    let onSave: () -> Void

    var body: some View {
        Section {
            RichTextField(
                text: $issue.solution,
                placeholder: "Document how this was resolved… (markdown supported)",
                onCommit: onSave
            )
        } header: {
            SwiftUI.Label("Solution", systemImage: "checkmark.seal")
                .foregroundStyle(.green)
        } footer: {
            if issue.solution.isEmpty {
                Text("Included when you Copy for AI.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssuePropertiesSection
// ─────────────────────────────────────────────────────────────────────────────

private struct IssuePropertiesSection: View {
    @Bindable var issue: Issue
    let onSave: () -> Void

    var body: some View {
        Section("Properties") {
            Picker(selection: $issue.status) {
                ForEach(IssueStatus.allCases, id: \.self) { status in
                    SwiftUI.Label(status.displayName, systemImage: status.glyph)
                        .tag(status)
                }
            } label: {
                SwiftUI.Label {
                    Text("Status")
                } icon: {
                    Image(systemName: issue.status.glyph)
                        .foregroundStyle(issue.status.color)
                }
            }
            .onChange(of: issue.status) { onSave() }

            Picker(selection: $issue.priority) {
                ForEach(IssuePriority.allCases, id: \.self) { priority in
                    SwiftUI.Label(priority.displayName, systemImage: priority.symbolName)
                        .tag(priority)
                }
            } label: {
                SwiftUI.Label {
                    Text("Priority")
                } icon: {
                    Image(systemName: issue.priority.symbolName)
                        .foregroundStyle(issue.priority.color)
                }
            }
            .onChange(of: issue.priority) { onSave() }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueDueDateSection
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueDueDateSection: View {
    @Bindable var issue: Issue
    let onSave: () -> Void
    @State private var hasDueDate: Bool

    init(issue: Issue, onSave: @escaping () -> Void) {
        self.issue = issue
        self.onSave = onSave
        _hasDueDate = State(initialValue: issue.dueDate != nil)
    }

    var body: some View {
        Section("Due Date") {
            Toggle("Has due date", isOn: $hasDueDate)
                .onChange(of: hasDueDate) {
                    issue.dueDate = hasDueDate ? (issue.dueDate ?? Date.now) : nil
                    onSave()
                }
            if hasDueDate {
                DatePicker(
                    "Due date",
                    selection: Binding(
                        get: { issue.dueDate ?? Date.now },
                        set: { issue.dueDate = $0; onSave() }
                    ),
                    displayedComponents: .date
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueMetadataFooter
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueMetadataFooter: View {
    let issue: Issue

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                Text("Created \(issue.createdAt.formatted(date: .abbreviated, time: .shortened))")
                Text("Updated \(issue.updatedAt.formatted(date: .abbreviated, time: .shortened))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CopyConfirmationPill
// Responsibility: render the floating "Copied · …" toast.
// ─────────────────────────────────────────────────────────────────────────────

private struct CopyConfirmationPill: View {
    let message: String?

    var body: some View {
        if let message {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message).font(.caption.weight(.medium))
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
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - LabelsRow
// ─────────────────────────────────────────────────────────────────────────────

private struct LabelsRow: View {
    @Bindable var issue: Issue
    @State private var showPicker = false

    var workspace: Workspace? { issue.project?.workspace }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FlowLayout(spacing: 4) {
                ForEach(issue.unwrappedLabels) { label in
                    LabelChip(name: label.name, colorHex: label.colorHex) {
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

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - FlowLayout (utility)
// ─────────────────────────────────────────────────────────────────────────────

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
