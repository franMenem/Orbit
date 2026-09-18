import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AttachmentsView
// Nocturne restyle: attachments render as a vertical list of rows (border
// #232532, radius 8, padding 8/10 — icon + filename 12pt + size 11pt
// Nocturne.textFaint) instead of the previous thumbnail grid. All attach/
// remove/preview/drag-drop logic is unchanged.
// ─────────────────────────────────────────────────────────────────────────────

struct AttachmentsView: View {
    @Bindable var issue: Issue
    @Environment(\.modelContext) private var context

    @State private var isDragTargeted = false
    @State private var showFilePicker  = false
    @State private var preview: Attachment? = nil

    /// One-off from the design spec, not in the Nocturne token set: the
    /// attachment row border (`#232532`).
    private let rowBorder = Color(hex: "#232532")

    var attachments: [Attachment] {
        (issue.attachments ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // ── Header ────────────────────────────────────────────────────
            HStack {
                if !attachments.isEmpty {
                    Text("\(attachments.count) file\(attachments.count == 1 ? "" : "s")")
                        .font(Nocturne.Font_.chip)
                        .foregroundStyle(Nocturne.textDim)
                }
                Spacer()
                Button {
                    showFilePicker = true
                } label: {
                    SwiftUI.Label("Add Files", systemImage: "plus")
                        .font(Nocturne.Font_.chip)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Nocturne.textDim)
            }

            // ── Drop zone / rows ──────────────────────────────────────────
            ZStack {
                if attachments.isEmpty {
                    // Empty state — dashed Nocturne box.
                    RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                        .fill(isDragTargeted ? Nocturne.accentTint : Color.clear)
                    RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                        .strokeBorder(
                            isDragTargeted ? Nocturne.accent : Nocturne.dashed,
                            style: StrokeStyle(lineWidth: isDragTargeted ? 1.5 : 1, dash: isDragTargeted ? [] : [4, 3])
                        )
                        .animation(.easeInOut(duration: 0.15), value: isDragTargeted)

                    VStack(spacing: 6) {
                        Image(systemName: isDragTargeted ? "arrow.down.circle" : "paperclip")
                            .font(.system(size: 20))
                            .foregroundStyle(isDragTargeted ? Nocturne.accent : Nocturne.textFaint)
                            .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
                        Text(isDragTargeted ? "Release to attach" : "Drop files or click Add Files")
                            .font(Nocturne.Font_.chip)
                            .foregroundStyle(Nocturne.textDim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 6) {
                        ForEach(attachments) { att in
                            AttachmentRow(
                                attachment: att,
                                borderColor: rowBorder,
                                onPreview: { preview = att },
                                onRemove:  { remove(att) }
                            )
                        }
                    }
                }
            }
            // Drag & drop from Finder
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDragTargeted) { providers in
                for provider in providers {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                        guard let data = item as? Data,
                              let url  = URL(dataRepresentation: data, relativeTo: nil) else { return }
                        DispatchQueue.main.async { attachFile(url: url) }
                    }
                }
                return true
            }
        }
        // ⌘V paste for this section is handled by a key-down NSEvent monitor
        // owned by IssueEditorView (IssueDetailView.swift), not by
        // `.onPasteCommand` here: that modifier only fires on the current
        // paste RESPONDER, and a plain VStack never becomes one, so it would
        // never fire regardless of scroll position. See
        // IssueEditorView.installPasteMonitor for the real handler — it
        // covers the whole detail panel, not just this section.
        // ── File importer (the correct SwiftUI API for file picking) ──────
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): urls.forEach { attachFile(url: $0) }
            case .failure: break
            }
        }
        // ── Image preview sheet ───────────────────────────────────────────
        .sheet(item: $preview) { att in
            ImagePreviewSheet(attachment: att)
        }
    }

    // MARK: - Helpers

    private func attachFile(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return }
        let uti = UTType(filenameExtension: url.pathExtension)?.identifier ?? UTType.data.identifier
        let att = Attachment(filename: url.lastPathComponent, contentType: uti, data: data)
        att.issue = issue
        if issue.attachments == nil { issue.attachments = [] }
        issue.attachments?.append(att)
        context.insert(att)
        try? context.save()
    }

    private func remove(_ att: Attachment) {
        issue.attachments?.removeAll { $0.persistentModelID == att.persistentModelID }
        context.delete(att)
        try? context.save()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AttachmentRow
// Nocturne row: border #232532, radius 8, padding 8/10, paperclip icon,
// filename 12pt, size 11pt Nocturne.textFaint. Remove button appears on hover.
// ─────────────────────────────────────────────────────────────────────────────

private struct AttachmentRow: View {
    let attachment: Attachment
    let borderColor: Color
    let onPreview: () -> Void
    let onRemove:  () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "paperclip")
                .font(.system(size: 12))
                .foregroundStyle(Nocturne.textDim)

            Text(attachment.filename)
                .font(Nocturne.Font_.inter(12))
                .foregroundStyle(Nocturne.textMuted)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Text(attachment.fileSizeString)
                .font(Nocturne.Font_.inter(11))
                .foregroundStyle(Nocturne.textFaint)

            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Nocturne.textFaint)
                }
                .buttonStyle(.plain)
                .help("Remove")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                .fill(isHovered ? Nocturne.surface : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Nocturne.Radius.row)
                .stroke(borderColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { tap() }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private func tap() {
        if attachment.isImage { onPreview() }
        else { openInDefaultApp() }
    }

    private func openInDefaultApp() {
        guard let data = attachment.data else { return }
        let name = attachment.filename.isEmpty ? "file" : attachment.filename
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: tmp)
        NSWorkspace.shared.open(tmp)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ImagePreviewSheet
// Non-private: reused by IssueCommentsSection (IssueDetailView.swift) for
// previewing comment image attachments — same module, no import needed.
// ─────────────────────────────────────────────────────────────────────────────

struct ImagePreviewSheet: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .font(Nocturne.Font_.inter(13, .medium))
                        .foregroundStyle(Nocturne.text)
                    Text(attachment.fileSizeString)
                        .font(Nocturne.Font_.chip)
                        .foregroundStyle(Nocturne.textDim)
                }
                Spacer()
                Button {
                    openInDefaultApp()
                } label: {
                    SwiftUI.Label("Open", systemImage: "arrow.up.right.square")
                        .font(Nocturne.Font_.control)
                }
                .buttonStyle(OutlineAccentButtonStyle())
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(OutlineAccentButtonStyle())
            }
            .padding(16)

            Rectangle().fill(Nocturne.border).frame(height: 1)

            // Image
            if let data = attachment.data, let img = NSImage(data: data) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 900, maxHeight: 700)
                        .padding(16)
                }
            } else {
                ContentUnavailableView("Cannot preview this file", systemImage: "eye.slash")
                    .frame(width: 480, height: 320)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .background(Nocturne.surface)
    }

    private func openInDefaultApp() {
        guard let data = attachment.data else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(attachment.filename.isEmpty ? "preview" : attachment.filename)
        try? data.write(to: tmp)
        NSWorkspace.shared.open(tmp)
    }
}
