import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Attachments section shown inside IssueDetailView.
/// Supports drag-and-drop from Finder and a file picker button.
struct AttachmentsView: View {
    @Bindable var issue: Issue
    @Environment(\.modelContext) private var context
    @State private var isDragTargeted = false
    @State private var previewAttachment: Attachment? = nil

    var attachments: [Attachment] {
        (issue.attachments ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Drop target + file list
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isDragTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: isDragTargeted ? 2 : 1, dash: [6])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDragTargeted
                                  ? Color.accentColor.opacity(0.07)
                                  : Color.secondary.opacity(0.04))
                    )

                if attachments.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "paperclip")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Drop files here or click Add")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 0) {
                        ForEach(attachments) { att in
                            AttachmentRow(attachment: att) {
                                remove(att)
                            } onPreview: {
                                previewAttachment = att
                            }
                            if att.id != attachments.last?.id {
                                Divider().padding(.leading, 36)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(minHeight: attachments.isEmpty ? 70 : nil)
            .dropDestination(for: URL.self) { urls, _ in
                attachFiles(urls: urls); return true
            } isTargeted: { isDragTargeted = $0 }

            // Add button
            Button {
                openFilePicker()
            } label: {
                SwiftUI.Label("Add Files", systemImage: "plus.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        // Quick-look preview for images
        .sheet(item: $previewAttachment) { att in
            AttachmentPreview(attachment: att)
        }
    }

    // MARK: - File handling

    private func attachFiles(urls: [URL]) {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }
            let uti = UTType(filenameExtension: url.pathExtension)?.identifier ?? "public.data"
            let att = Attachment(filename: url.lastPathComponent, contentType: uti, data: data)
            att.issue = issue
            if issue.attachments == nil { issue.attachments = [] }
            issue.attachments?.append(att)
            context.insert(att)
        }
        try? context.save()
    }

    private func remove(_ att: Attachment) {
        issue.attachments?.removeAll { $0.persistentModelID == att.persistentModelID }
        context.delete(att)
        try? context.save()
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Select files to attach to this issue"
        if panel.runModal() == .OK {
            attachFiles(urls: panel.urls)
        }
    }
}

// MARK: - AttachmentRow

private struct AttachmentRow: View {
    let attachment: Attachment
    let onRemove: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail or icon
            Group {
                if attachment.isImage, let data = attachment.data, let nsImg = NSImage(data: data) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: fileIcon(for: attachment.contentType))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.filename)
                    .font(.caption)
                    .lineLimit(1)
                Text(attachment.fileSizeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Preview button (images)
            if attachment.isImage {
                Button { onPreview() } label: {
                    Image(systemName: "eye")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Preview")
            }

            // Open in Finder / default app
            Button {
                openInDefaultApp(attachment)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Open")

            // Remove
            Button(role: .destructive) { onRemove() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Remove")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func fileIcon(for contentType: String) -> String {
        if contentType.contains("pdf")    { return "doc.richtext" }
        if contentType.contains("video")  { return "play.rectangle" }
        if contentType.contains("audio")  { return "waveform" }
        if contentType.contains("zip") || contentType.contains("archive") { return "archivebox" }
        if contentType.contains("text")   { return "doc.text" }
        if contentType.contains("spreadsheet") || contentType.contains("excel") { return "tablecells" }
        return "paperclip"
    }

    private func openInDefaultApp(_ att: Attachment) {
        guard let data = att.data else { return }
        // Write to a temp file and open with NSWorkspace
        let ext = att.filename.contains(".")
            ? String(att.filename.split(separator: ".").last ?? "bin")
            : "bin"
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(att.filename.isEmpty ? "file.\(ext)" : att.filename)
        try? data.write(to: tmp)
        NSWorkspace.shared.open(tmp)
    }
}

// MARK: - AttachmentPreview

private struct AttachmentPreview: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let data = attachment.data, let nsImg = NSImage(data: data) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 800, maxHeight: 600)
            } else {
                ContentUnavailableView("Cannot preview", systemImage: "eye.slash")
                    .frame(width: 400, height: 300)
            }
            Divider()
            HStack {
                Text(attachment.filename).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
    }
}
