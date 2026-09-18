import AppKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
// Nocturne restyle: `Form(.grouped)` is gone — this is a ScrollView + VStack
// column that fills whatever width its container gives it (the Shell 1b
// overlay in RootSplitView pins that to 540pt), `bgDeep` background, and its
// own 1pt divider on the leading edge — this view is no longer a
// NavigationSplitView column (which would draw that seam for free), it's an
// overlaid panel, so the divider has to be self-drawn.
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueEditorView: View {
    @Bindable var issue: Issue
    @Environment(\.modelContext) private var context
    @Environment(AppActions.self) private var appActions
    @State private var copyConfirmation: String? = nil
    @FocusState private var isTitleFocused: Bool
    @State private var pasteMonitor: Any? = nil

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

                    IssueCommentsSection(issue: issue)

                    IssueMetadataFooter(issue: issue)
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity)
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
        .onAppear { installPasteMonitor() }
        .onDisappear { removePasteMonitor() }
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

    // MARK: - ⌘V paste (issue-level attachments)
    //
    // `.onPasteCommand` only fires on the current paste RESPONDER. Nothing in
    // this panel besides the title/description/solution fields and the
    // comment composer — all NSTextView-backed — is ever a responder, so a
    // plain section VStack (e.g. Attachments) never receives it, no matter
    // where it's attached. A bare ⌘V while just browsing the panel needs a
    // local NSEvent monitor instead: it inspects the key window's first
    // responder and only intercepts when the user is NOT mid-edit in a text
    // field, so normal text paste (title, description, solution, comments)
    // is completely unaffected and keeps working exactly as before.
    //
    // The monitor is installed per-panel-appearance (`.onAppear`/
    // `.onDisappear`, token in `@State`) — `IssueDetailView` gives
    // `IssueEditorView` a fresh identity per issue via `.id(_:)`, so this
    // naturally reinstalls (with the right `issue` captured) whenever the
    // selected issue changes, and tears down when the panel closes.
    private func installPasteMonitor() {
        guard pasteMonitor == nil else { return }
        pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "v" else { return event }

            // Let normal text paste proceed for title/description/solution/
            // comment composer — all NSTextView-backed under the hood.
            if let responder = NSApp.keyWindow?.firstResponder, responder is NSText {
                return event
            }

            guard let imported = PastedImageImporter.importFromGeneralPasteboard() else { return event }
            attachPastedImage(imported)
            return nil
        }
    }

    private func removePasteMonitor() {
        if let pasteMonitor {
            NSEvent.removeMonitor(pasteMonitor)
        }
        pasteMonitor = nil
    }

    /// Turns one image found on the general pasteboard into an issue-level
    /// Attachment — mirrors `AttachmentsView.attachFile`.
    private func attachPastedImage(_ imported: PastedImageImporter.Imported) {
        guard let png = PastedImageImporter.normalizedPNG(from: imported.data) else { return }
        let att = Attachment(
            filename: PastedImageImporter.pastedImageFilename(),
            contentType: UTType.png.identifier,
            data: png
        )
        att.issue = issue
        if issue.attachments == nil { issue.attachments = [] }
        issue.attachments?.append(att)
        context.insert(att)
        try? context.save()
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

    @State private var showingPicker = false

    private var dateBinding: Binding<Date> {
        Binding(
            get: { issue.dueDate ?? .now },
            set: { issue.dueDate = $0; onSave() }
        )
    }

    var body: some View {
        // Menu content on macOS renders as NSMenu items, which can't host an
        // interactive DatePicker — use a popover instead so the calendar
        // actually responds to clicks.
        Button {
            showingPicker.toggle()
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
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            VStack(spacing: 8) {
                DatePicker("Due date", selection: dateBinding, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                if issue.dueDate != nil {
                    Divider()
                    Button("Clear Due Date", role: .destructive) {
                        issue.dueDate = nil
                        onSave()
                        showingPicker = false
                    }
                }
            }
            .padding(12)
        }
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
    @State private var showingNewLabelSheet = false

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
            if workspace != nil {
                Divider()
                Button("New Label…") { showingNewLabelSheet = true }
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
        .sheet(isPresented: $showingNewLabelSheet) {
            if let workspace {
                NewLabelSheet(workspace: workspace) { label in
                    toggle(label: label, attached: false)
                }
            }
        }
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
// MARK: - IssueCommentsSection
// Linear-style comments: oldest-first list + a bottom composer that accepts
// pasted images (⌘V) as pending thumbnails and posts on ⌘Enter or the
// "Comment" button. Reuses `ImagePreviewSheet` (AttachmentsView.swift) for
// full-size previews instead of duplicating it.
// ─────────────────────────────────────────────────────────────────────────────

private struct IssueCommentsSection: View {
    @Bindable var issue: Issue
    @Environment(\.modelContext) private var context

    @State private var draftText = ""
    @State private var pendingImages: [PendingCommentImage] = []
    @State private var preview: Attachment? = nil

    private var canSubmit: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingImages.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaps(text: "Comments")

            if !issue.unwrappedComments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(issue.unwrappedComments) { comment in
                        CommentRow(
                            comment: comment,
                            onDelete: { delete(comment) },
                            onPreview: { preview = $0 }
                        )
                        if comment.id != issue.unwrappedComments.last?.id {
                            Rectangle().fill(Nocturne.rowLine).frame(height: 1)
                        }
                    }
                }
            }

            CommentComposer(
                text: $draftText,
                pendingImages: $pendingImages,
                canSubmit: canSubmit,
                onSubmit: submit
            )
        }
        .sheet(item: $preview) { att in
            ImagePreviewSheet(attachment: att)
        }
    }

    private func submit() {
        guard canSubmit else { return }

        let comment = Comment(text: draftText.trimmingCharacters(in: .whitespacesAndNewlines))
        comment.issue = issue
        if issue.comments == nil { issue.comments = [] }
        issue.comments?.append(comment)
        context.insert(comment)

        for pending in pendingImages {
            // NOT `issue` — comment images live only on `comment.attachments`
            // so issue-level attachment lists never pick them up.
            let att = Attachment(
                filename: PastedImageImporter.pastedImageFilename(),
                contentType: UTType.png.identifier,
                data: pending.data
            )
            att.comment = comment
            if comment.attachments == nil { comment.attachments = [] }
            comment.attachments?.append(att)
            context.insert(att)
        }

        try? context.save()
        draftText = ""
        pendingImages = []
    }

    private func delete(_ comment: Comment) {
        issue.comments?.removeAll { $0.persistentModelID == comment.persistentModelID }
        context.delete(comment)   // cascades comment.attachments — see Comment.swift
        try? context.save()
    }
}

/// One posted comment: relative timestamp, text, and (optionally) images
/// rendered inline at content width, Linear-style — readable without
/// clicking through. Delete button appears on hover.
private struct CommentRow: View {
    let comment: Comment
    let onDelete: () -> Void
    let onPreview: (Attachment) -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(comment.createdAt.formatted(.relative(presentation: .named)))
                    .font(Nocturne.Font_.inter(11))
                    .foregroundStyle(Nocturne.textFaint)
                Spacer(minLength: 8)
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Nocturne.textFaint)
                    }
                    .buttonStyle(.plain)
                    .help("Delete comment")
                }
            }

            if !comment.text.isEmpty {
                Text(comment.text)
                    .font(Nocturne.Font_.inter(13))
                    .foregroundStyle(Nocturne.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !comment.unwrappedAttachments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(comment.unwrappedAttachments) { att in
                        CommentImageInline(attachment: att) { onPreview(att) }
                    }
                }
            }
        }
        .onHover { isHovered = $0 }
    }
}

/// Full-content-width, clickable inline render of a comment's image
/// attachment (Linear-style — readable in the comment itself, no click
/// needed to see it). Capped at `maxHeight` so a huge screenshot can't take
/// over the panel; click still opens `ImagePreviewSheet` for full size.
private struct CommentImageInline: View {
    let attachment: Attachment
    let onTap: () -> Void

    private let maxHeight: CGFloat = 320

    var body: some View {
        Group {
            if let data = attachment.data, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: maxHeight)
                    .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.row))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                .stroke(Nocturne.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

/// An image pasted into the composer but not yet posted.
private struct PendingCommentImage: Identifiable {
    let id = UUID()
    let data: Data
}

/// Bottom composer: plain multiline field + pending-image thumbnails +
/// "Comment" button. Accepts ⌘V of clipboard images (screenshots arrive as
/// PNG/TIFF; image file URLs also work) and ⌘Enter to submit.
private struct CommentComposer: View {
    @Binding var text: String
    @Binding var pendingImages: [PendingCommentImage]
    let canSubmit: Bool
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Leave a comment…")
                        .font(Nocturne.Font_.body)
                        .foregroundStyle(Nocturne.textFaint)
                        .padding(.top, 9)
                        .padding(.leading, 11)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(Nocturne.Font_.body)
                    .foregroundStyle(Nocturne.text)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 56, maxHeight: 120)
                    .focused($isFocused)
            }
            .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.row))
            .overlay(
                RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                    .strokeBorder(isFocused ? Nocturne.accent : Nocturne.border, lineWidth: isFocused ? 1.5 : 1)
            )
            .animation(.easeInOut(duration: 0.12), value: isFocused)
            .onPasteCommand(of: [
                UTType.png.identifier,
                UTType.tiff.identifier,
                UTType.image.identifier,
                UTType.fileURL.identifier,
            ]) { providers in
                PastedImageImporter.importImages(from: providers) { imported in
                    for image in imported {
                        guard let png = PastedImageImporter.normalizedPNG(from: image.data) else { continue }
                        pendingImages.append(PendingCommentImage(data: png))
                    }
                }
            }

            if !pendingImages.isEmpty {
                HStack(spacing: 8) {
                    ForEach(pendingImages) { pending in
                        PendingCommentImageThumb(pending: pending) {
                            pendingImages.removeAll { $0.id == pending.id }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack {
                Spacer()
                Button("Comment", action: submitAndClearFocus)
                    .buttonStyle(OutlineAccentButtonStyle())
                    .disabled(!canSubmit)
            }
        }
        // Hidden ⌘Enter shortcut — fires even while the TextEditor has focus.
        .background(
            Button(action: submitAndClearFocus) { EmptyView() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canSubmit)
                .opacity(0)
                .frame(width: 0, height: 0)
        )
    }

    private func submitAndClearFocus() {
        onSubmit()
        isFocused = false
    }
}

/// Small removable thumbnail for an image pending in the composer.
private struct PendingCommentImageThumb: View {
    let pending: PendingCommentImage
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let img = NSImage(data: pending.data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.chip))
                    .overlay(
                        RoundedRectangle(cornerRadius: Nocturne.Radius.chip)
                            .stroke(Nocturne.border, lineWidth: 1)
                    )
            }
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Nocturne.text)
                    .background(Circle().fill(Nocturne.bgDeep))
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
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
