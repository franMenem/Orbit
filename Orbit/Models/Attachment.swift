import Foundation
import SwiftData

/// File attachment on an Issue. Binary data stored externally (not inline in
/// SQLite) via @Attribute(.externalStorage), which is CloudKit-compatible.
@Model
final class Attachment {
    var id: UUID = UUID()
    var filename: String = ""
    var contentType: String = ""    // UTType identifier, e.g. "public.jpeg"
    var fileSize: Int = 0           // bytes
    var createdAt: Date = Date.now

    /// Raw file bytes. Stored outside the SQLite store (as a sidecar file).
    /// SwiftData + CloudKit automatically handles this as a CKAsset.
    @Attribute(.externalStorage)
    var data: Data? = nil

    var issue: Issue? = nil

    init(filename: String = "", contentType: String = "", data: Data? = nil) {
        self.filename    = filename
        self.contentType = contentType
        self.data        = data
        self.fileSize    = data?.count ?? 0
    }

    /// True when the content type indicates an image.
    var isImage: Bool {
        contentType.hasPrefix("image/") ||
        contentType == "public.jpeg" ||
        contentType == "public.png" ||
        contentType == "public.gif" ||
        contentType == "public.heic"
    }

    /// Human-readable file size string.
    var fileSizeString: String {
        let bytes = Double(fileSize)
        if bytes < 1_000 { return "\(fileSize) B" }
        if bytes < 1_000_000 { return String(format: "%.1f KB", bytes / 1_000) }
        return String(format: "%.1f MB", bytes / 1_000_000)
    }
}
