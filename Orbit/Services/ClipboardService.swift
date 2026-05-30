import AppKit
import Foundation

/// Builds a clipboard package designed for pasting into AI chat tools
/// (Claude, ChatGPT, Gemini, etc).
///
/// What goes on the clipboard:
///   • **Markdown text** — title, metadata, details, attachment list
///   • **First image as image data** — if any image attachment exists,
///     it's added as TIFF + PNG so the AI tool's "paste image" handler
///     picks it up
///   • **File URLs** — every attachment is written to a temp directory
///     and its URL is added so apps like Finder/Mail accept them as files
///
/// The receiving app picks whichever representation it prefers.
enum ClipboardService {

    struct CopyResult {
        let imageCount: Int
        let nonImageCount: Int
        var totalFiles: Int { imageCount + nonImageCount }

        /// Short user-facing description, e.g. "Copied · 2 images · 1 file"
        var summary: String {
            var parts: [String] = ["Copied"]
            if imageCount > 0 {
                parts.append("\(imageCount) image\(imageCount == 1 ? "" : "s")")
            }
            if nonImageCount > 0 {
                parts.append("\(nonImageCount) file\(nonImageCount == 1 ? "" : "s")")
            }
            return parts.joined(separator: " · ")
        }
    }

    /// Copies the full issue to the system pasteboard in a form optimised for AI tools.
    @discardableResult
    static func copyIssueForAI(_ issue: Issue) -> CopyResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let markdown    = buildMarkdown(for: issue)
        let attachments = issue.attachments ?? []

        // ── Write attachments to a fresh temp directory ──────────────────
        var fileURLs: [URL] = []
        var firstImage: (data: Data, contentType: String)? = nil
        var imageCount = 0
        var nonImageCount = 0

        if !attachments.isEmpty {
            let tmpDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("Orbit-clipboard-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

            for att in attachments {
                guard let data = att.data else { continue }
                let safe = att.filename.isEmpty
                    ? "file-\(att.id.uuidString).bin"
                    : att.filename
                let url = tmpDir.appendingPathComponent(safe)
                if (try? data.write(to: url)) != nil {
                    fileURLs.append(url)
                }
                if att.isImage {
                    imageCount += 1
                    if firstImage == nil {
                        firstImage = (data, att.contentType)
                    }
                } else {
                    nonImageCount += 1
                }
            }
        }

        // ── Build the primary pasteboard item: text + (optional) image ──
        let textItem = NSPasteboardItem()
        textItem.setString(markdown, forType: .string)

        if let firstImage,
           let nsImage = NSImage(data: firstImage.data) {
            // TIFF is the universal macOS image type — always include it
            if let tiff = nsImage.tiffRepresentation {
                textItem.setData(tiff, forType: .tiff)
            }
            // Add PNG representation when source is PNG (preserves transparency)
            if firstImage.contentType.contains("png") {
                textItem.setData(firstImage.data, forType: .png)
            }
        }

        // ── Add file URLs as separate items so multi-file paste works ────
        let urlItems: [NSPasteboardItem] = fileURLs.map { url in
            let item = NSPasteboardItem()
            item.setString(url.absoluteString, forType: .fileURL)
            return item
        }

        pasteboard.writeObjects([textItem] + urlItems)

        return CopyResult(imageCount: imageCount, nonImageCount: nonImageCount)
    }

    /// Copies ONLY the markdown text — no images, no files.
    @discardableResult
    static func copyIssueAsMarkdown(_ issue: Issue) -> CopyResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(buildMarkdown(for: issue), forType: .string)
        return CopyResult(imageCount: 0, nonImageCount: 0)
    }

    // MARK: - Markdown builder

    private static func buildMarkdown(for issue: Issue) -> String {
        var lines: [String] = []

        // Title
        let title = issue.title.isEmpty ? "Untitled" : issue.title
        lines.append("# \(title)")
        lines.append("")

        // Meta line
        var meta: [String] = []
        meta.append("**Status:** \(issue.status.displayName)")
        meta.append("**Priority:** \(issue.priority.displayName)")
        if let due = issue.dueDate {
            meta.append("**Due:** \(due.formatted(date: .abbreviated, time: .omitted))")
        }
        let labelNames = issue.unwrappedLabels.map(\.name)
        if !labelNames.isEmpty {
            meta.append("**Labels:** \(labelNames.joined(separator: ", "))")
        }
        if let project = issue.project?.name {
            let workspace = issue.project?.workspace?.name
            meta.append("**Project:** \(workspace.map { "\($0) / \(project)" } ?? project)")
        }
        if !meta.isEmpty {
            lines.append(meta.joined(separator: " · "))
            lines.append("")
        }

        // Details
        if !issue.details.isEmpty {
            lines.append("## Details")
            lines.append("")
            lines.append(issue.details)
            lines.append("")
        }

        // Attachment list (just names; the bytes are on the pasteboard separately)
        let attachments = issue.attachments ?? []
        if !attachments.isEmpty {
            lines.append("---")
            lines.append("**Attachments (\(attachments.count)):**")
            for att in attachments {
                let kind = att.isImage ? "🖼️" : "📄"
                lines.append("- \(kind) \(att.filename) (\(att.fileSizeString))")
            }
        }

        return lines.joined(separator: "\n")
    }
}
