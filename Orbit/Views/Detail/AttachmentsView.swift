import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - AttachmentsView
// ─────────────────────────────────────────────────────────────────────────────

struct AttachmentsView: View {
    @Bindable var issue: Issue
    @Environment(\.modelContext) private var context

    @State private var isDragTargeted = false
    @State private var showFilePicker  = false
    @State private var preview: Attachment? = nil

    var attachments: [Attachment] {
        (issue.attachments ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    // Adaptive grid: min 100px per card, fills available width
    let columns = [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Header ────────────────────────────────────────────────────
            HStack {
                if !attachments.isEmpty {
                    Text("\(attachments.count) file\(attachments.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showFilePicker = true
                } label: {
                    SwiftUI.Label("Add Files", systemImage: "plus")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // ── Drop zone / grid ──────────────────────────────────────────
            ZStack {
                // Background + border
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDragTargeted
                          ? Color.accentColor.opacity(0.08)
                          : Color.primary.opacity(0.03))
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isDragTargeted ? Color.accentColor : Color.primary.opacity(0.12),
                        style: StrokeStyle(lineWidth: isDragTargeted ? 2 : 1, dash: isDragTargeted ? [] : [5, 4])
                    )
                    .animation(.easeInOut(duration: 0.15), value: isDragTargeted)

                if attachments.isEmpty {
                    // Empty state
                    VStack(spacing: 8) {
                        Image(systemName: isDragTargeted ? "arrow.down.circle.fill" : "paperclip.circle")
                            .font(.system(size: 28))
                            .foregroundStyle(isDragTargeted ? Color.accentColor : Color.secondary.opacity(0.5))
                            .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
                        Text(isDragTargeted ? "Release to attach" : "Drop files or click Add Files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    // File grid
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(attachments) { att in
                            AttachmentCard(
                                attachment: att,
                                onPreview: { preview = att },
                                onRemove:  { remove(att) }
                            )
                        }
                    }
                    .padding(12)
                }
            }
            .frame(minHeight: attachments.isEmpty ? 80 : nil)
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
// MARK: - AttachmentCard
// ─────────────────────────────────────────────────────────────────────────────

private struct AttachmentCard: View {
    let attachment: Attachment
    let onPreview: () -> Void
    let onRemove:  () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card body
            Button(action: tap) {
                VStack(spacing: 0) {
                    // ── Thumbnail / icon area ─────────────────────────────
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(iconBackgroundColor.opacity(0.12))
                            .frame(height: 80)

                        if attachment.isImage,
                           let data = attachment.data,
                           let img  = NSImage(data: data) {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: fileSymbol)
                                .font(.system(size: 28))
                                .foregroundStyle(iconBackgroundColor)
                        }
                    }

                    // ── Filename + size ───────────────────────────────────
                    VStack(spacing: 2) {
                        Text(attachment.filename)
                            .font(.caption2.weight(.medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)

                        Text(attachment.fileSizeString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                }
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // ── Delete button — visible on hover ─────────────────────────
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .help("Remove")
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
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

    // ── Visual metadata ───────────────────────────────────────────────────

    private var fileSymbol: String {
        let ct = attachment.contentType
        if ct.contains("pdf")                        { return "doc.richtext.fill" }
        if ct.contains("video")                      { return "play.rectangle.fill" }
        if ct.contains("audio")                      { return "waveform" }
        if ct.contains("zip") || ct.contains("archive") { return "archivebox.fill" }
        if ct.contains("spreadsheet") || ct.contains("excel") || ct.contains("numbers") {
            return "tablecells.fill"
        }
        if ct.contains("presentation") || ct.contains("keynote") || ct.contains("powerpoint") {
            return "chart.bar.doc.horizontal.fill"
        }
        if ct.contains("text") || ct.contains("word") || ct.contains("pages") {
            return "doc.text.fill"
        }
        if ct.contains("image")                      { return "photo.fill" }
        return "doc.fill"
    }

    private var iconBackgroundColor: Color {
        let ct = attachment.contentType
        if ct.contains("pdf")                        { return .red }
        if ct.contains("video")                      { return .purple }
        if ct.contains("audio")                      { return .orange }
        if ct.contains("zip") || ct.contains("archive") { return .yellow }
        if ct.contains("spreadsheet") || ct.contains("excel") || ct.contains("numbers") {
            return .green
        }
        if ct.contains("presentation") || ct.contains("keynote") || ct.contains("powerpoint") {
            return .orange }
        if ct.contains("text") || ct.contains("word") || ct.contains("pages") {
            return .blue }
        return .secondary
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - ImagePreviewSheet
// ─────────────────────────────────────────────────────────────────────────────

private struct ImagePreviewSheet: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .font(.headline)
                    Text(attachment.fileSizeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    openInDefaultApp()
                } label: {
                    SwiftUI.Label("Open", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(16)

            Divider()

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
        .background(.background)
    }

    private func openInDefaultApp() {
        guard let data = attachment.data else { return }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(attachment.filename.isEmpty ? "preview" : attachment.filename)
        try? data.write(to: tmp)
        NSWorkspace.shared.open(tmp)
    }
}
