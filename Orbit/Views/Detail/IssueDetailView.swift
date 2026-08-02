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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Nocturne.bgDeep)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueEditorView (composer)
// Responsibility: arrange sections + own the copy-confirmation toast state.
// All editing logic is delegated to focused sub-views.
//
// Nocturne restyle: `Form(.grouped)` is gone — this is a fixed-width
// (404pt) ScrollView + VStack column, `bgDeep` background, divider on the
// leading edge (drawn by the parent split view's own divider elsewhere, but
// we render one here too since this view can also be used stand-alone).
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueEditorView: View {
    @Bindable var issue: Issue
    @Environment(\.modelContext) private var context
    @Environment(AppActions.self) private var appActions
    @State private var copyConfirmation: String? = nil
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            IssueDetailToolbar(issue: issue, onCopyDone: showConfirmation)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    IssueTitleField(issue: issue, isTitleFocused: $isTitleFocused, onSave: save)

                    IssuePropertiesGrid(issue: issue, onSave: save)

                    FadingRule()

                    IssueDetailSection(issue: issue, onSave: save)

                    IssueSolutionSection(issue: issue, onSave: save)

                    IssueAttachmentsSection(issue: issue)

                    IssueMetadataFooter(issue: issue)
                }
                .padding(16)
            }
        }
        .frame(width: 404)
        .frame(maxHeight: .infinity)
        .background(Nocturne.bgDeep)
        .overlay(alignment: .leading) {
            Rectangle().fill(Nocturne.divider).frame(width: 1)
        }
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
// MARK: - IssueDetailToolbar
// Code · status pill · spacer · "Copy for AI" outline button · ellipsis menu.
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueDetailToolbar: View {
    let issue: Issue
    let onCopyDone: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(issue.code.isEmpty ? "—" : issue.code)
                .font(Nocturne.Font_.inter(11))
                .foregroundStyle(Nocturne.textDim)

            DetailStatusPill(status: issue.status)

            Spacer(minLength: 8)

            Button {
                copyForAI()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkle").font(.system(size: 12, weight: .medium))
                    Text("Copy for AI").font(Nocturne.Font_.inter(12, .medium))
                }
            }
            .buttonStyle(OutlineAccentButtonStyle())
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .help("Copy this issue to the clipboard (⇧⌘C)")

            // Secondary menu — "Copy as Markdown only" (the sparkle button
            // above already covers the primary "Copy for AI" action).
            Menu {
                Button { copyMarkdown() } label: {
                    SwiftUI.Label("Copy as Markdown only", systemImage: "doc.plaintext")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Nocturne.textDim)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(hex: "#1E2130")).frame(height: 1)
        }
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

/// Status pill for the detail toolbar — icon + name, pill radius, fill =
/// `status.tint`, text = `status.color`, 11pt, padding 2/9. Built inline per
/// spec rather than reusing `StatusPill` (IssueRow.swift), which is sized
/// differently (12pt / sm padding) for the list row context.
private struct DetailStatusPill: View {
    let status: IssueStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.glyph).font(.system(size: 10))
            Text(status.displayName).font(Nocturne.Font_.inter(11, .medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 2)
        .foregroundStyle(status.color)
        .background(status.tint, in: Capsule())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueTitleField
// 19pt/500 inline-editable title, no TextField chrome.
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueTitleField: View {
    @Bindable var issue: Issue
    @FocusState.Binding var isTitleFocused: Bool
    let onSave: () -> Void

    var body: some View {
        TextField("Untitled", text: $issue.title)
            .textFieldStyle(.plain)
            .font(Nocturne.Font_.issueTitle)
            .foregroundStyle(Nocturne.text)
            .lineSpacing(4)
            .focused($isTitleFocused)
            .onChange(of: issue.title) { onSave() }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssuePropertiesGrid
// 2-column grid (88px label / value): Status, Priority, Due, Labels. Each
// value opens a Menu — replaces the long-label Pickers used previously.
// ─────────────────────────────────────────────────────────────────────────────

private struct IssuePropertiesGrid: View {
    @Bindable var issue: Issue
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            propertyRow("Status") { StatusMenuValue(issue: issue, onSave: onSave) }
            propertyRow("Priority") { PriorityMenuValue(issue: issue, onSave: onSave) }
            propertyRow("Due") { DueDateMenuValue(issue: issue, onSave: onSave) }
            propertyRow("Labels") { IssueLabelsValue(issue: issue) }
        }
    }

    @ViewBuilder
    private func propertyRow<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(Nocturne.Font_.inter(11.5))
                .foregroundStyle(Nocturne.textDim)
                .frame(width: 88, alignment: .leading)
                .padding(.top, 2)
            value()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Trailing caret shared by every property-grid Menu trigger.
private struct MenuCaret: View {
    var body: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 10))
            .foregroundStyle(Nocturne.textFaint)
    }
}

private struct StatusMenuValue: View {
    @Bindable var issue: Issue
    let onSave: () -> Void

    var body: some View {
        Menu {
            ForEach(IssueStatus.allCases, id: \.self) { status in
                Button {
                    issue.status = status
                    onSave()
                } label: {
                    SwiftUI.Label(status.displayName, systemImage: status.glyph)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: issue.status.glyph)
                    .font(.system(size: 12))
                    .foregroundStyle(issue.status.color)
                Text(issue.status.displayName)
                    .font(Nocturne.Font_.control)
                    .foregroundStyle(Nocturne.textMuted)
                Spacer(minLength: 0)
                MenuCaret()
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

private struct PriorityMenuValue: View {
    @Bindable var issue: Issue
    let onSave: () -> Void

    var body: some View {
        Menu {
            ForEach(IssuePriority.allCases, id: \.self) { priority in
                Button {
                    issue.priority = priority
                    onSave()
                } label: {
                    Text(priority.displayName)
                }
            }
        } label: {
            HStack(spacing: 6) {
                PriorityBars(priority: issue.priority)
                Text(issue.priority.displayName)
                    .font(Nocturne.Font_.control)
                    .foregroundStyle(Nocturne.textMuted)
                Spacer(minLength: 0)
                MenuCaret()
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

private struct DueDateMenuValue: View {
    @Bindable var issue: Issue
    let onSave: () -> Void

    private var dateBinding: Binding<Date> {
        Binding(
            get: { issue.dueDate ?? .now },
            set: { issue.dueDate = $0; onSave() }
        )
    }

    var body: some View {
        Menu {
            DatePicker("Due date", selection: dateBinding, displayedComponents: .date)
                .labelsHidden()
            if issue.dueDate != nil {
                Divider()
                Button("Clear Due Date", role: .destructive) {
                    issue.dueDate = nil
                    onSave()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(Nocturne.textDim)
                Text(dueDateText)
                    .font(Nocturne.Font_.control)
                    .foregroundStyle(issue.dueDate == nil ? Nocturne.textFaint : Nocturne.textMuted)
                Spacer(minLength: 0)
                MenuCaret()
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private var dueDateText: String {
        guard let due = issue.dueDate else { return "No due date" }
        return due.formatted(date: .abbreviated, time: .omitted)
    }
}

/// Labels value — shows the attached chips (flow-wrapped) and opens a Menu
/// that toggles every workspace label on/off, mirroring the attach/detach
/// logic previously in `LabelPickerView`.
private struct IssueLabelsValue: View {
    @Bindable var issue: Issue
    @Environment(\.modelContext) private var context

    private var workspace: Workspace? { issue.project?.workspace }

    var body: some View {
        Menu {
            if let ws = workspace, !ws.unwrappedLabels.isEmpty {
                ForEach(ws.unwrappedLabels) { label in
                    let attached = issue.unwrappedLabels.contains {
                        $0.persistentModelID == label.persistentModelID
                    }
                    Button {
                        toggle(label: label, attached: attached)
                    } label: {
                        if attached {
                            SwiftUI.Label(label.name, systemImage: "checkmark")
                        } else {
                            Text(label.name)
                        }
                    }
                }
            } else {
                Text("No labels in this workspace")
            }
        } label: {
            HStack(alignment: .top, spacing: 6) {
                if issue.unwrappedLabels.isEmpty {
                    Text("No labels")
                        .font(Nocturne.Font_.control)
                        .foregroundStyle(Nocturne.textFaint)
                } else {
                    FlowLayout(spacing: 4) {
                        ForEach(issue.unwrappedLabels) { label in
                            LabelChip(name: label.name, colorHex: label.colorHex)
                        }
                    }
                }
                Spacer(minLength: 0)
                MenuCaret().padding(.top, 3)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    // `Orbit.Label` disambiguates from `SwiftUI.Label`, both visible here —
    // same convention as `LabelPickerView.swift`.
    private func toggle(label: Orbit.Label, attached: Bool) {
        if attached {
            issue.labels?.removeAll { $0.persistentModelID == label.persistentModelID }
            label.issues?.removeAll { $0.persistentModelID == issue.persistentModelID }
        } else {
            if issue.labels == nil { issue.labels = [] }
            issue.labels?.append(label)
            if label.issues == nil { label.issues = [] }
            label.issues?.append(issue)
        }
        try? context.save()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueDetailSection ("Details")
// Header in SectionCaps; body renders through RichTextField/MarkdownText,
// which now carries the Nocturne body/bullet typography itself.
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueDetailSection: View {
    @Bindable var issue: Issue
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaps(text: "Details")
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
// `seal-check` glyph (SF: checkmark.seal) in Nocturne.accent — no longer
// green. Empty state is a dashed Nocturne box.
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueSolutionSection: View {
    @Bindable var issue: Issue
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 13))
                    .foregroundStyle(Nocturne.accent)
                SectionCaps(text: "Solution")
            }

            RichTextField(
                text: $issue.solution,
                placeholder: "Todavía sin documentar. Se incluye en Copy for AI cuando la escribas.",
                dashedWhenEmpty: true,
                onCommit: onSave
            )
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueAttachmentsSection
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueAttachmentsSection: View {
    @Bindable var issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaps(text: "Attachments")
            AttachmentsView(issue: issue)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - IssueMetadataFooter
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueMetadataFooter: View {
    let issue: Issue

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Rectangle().fill(Color(hex: "#1E2130")).frame(height: 1)
                .padding(.bottom, 10)
            Text("Created \(issue.createdAt.formatted(date: .abbreviated, time: .shortened))")
            Text("Updated \(issue.updatedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        .font(Nocturne.Font_.inter(11))
        .foregroundStyle(Nocturne.textFaint)
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
                    .foregroundStyle(Nocturne.accentText)
                Text(message).font(Nocturne.Font_.control.weight(.medium))
            }
            .foregroundStyle(Nocturne.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Nocturne.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Nocturne.borderHover, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.35), radius: 6, y: 2)
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
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
