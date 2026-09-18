import AppKit
import Foundation
import UniformTypeIdentifiers

/// Shared image-paste helper. Backs two different entry points:
///   • `importImages(from:)` — the comment composer's `.onPasteCommand`,
///     which SwiftUI hands a batch of `NSItemProvider`s.
///   • `importFromGeneralPasteboard()` — the issue detail panel's ⌘V key
///     monitor (IssueEditorView.installPasteMonitor), which reads
///     `NSPasteboard.general` directly since nothing outside a text field in
///     that panel is ever a paste responder.
/// Both paths converge on the same `Imported` shape and `normalizedPNG`/
/// `pastedImageFilename` helpers below, so every pasted image ends up as an
/// identically-shaped Attachment regardless of how it arrived.
enum PastedImageImporter {
    struct Imported {
        let data: Data
        let contentType: String  // UTType identifier, e.g. "public.png"
    }

    /// Asynchronously resolves every image found among `providers`, in the
    /// order they were provided. Calls `completion` on the main queue once
    /// all providers have been inspected (non-image items are skipped).
    static func importImages(from providers: [NSItemProvider], completion: @escaping ([Imported]) -> Void) {
        let group = DispatchGroup()
        var results: [(Int, Imported)] = []
        let lock = NSLock()

        for (index, provider) in providers.enumerated() {
            if let imageType = provider.registeredTypeIdentifiers.first(where: {
                UTType($0)?.conforms(to: .image) == true
            }) {
                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: imageType) { data, _ in
                    defer { group.leave() }
                    guard let data else { return }
                    lock.lock()
                    results.append((index, Imported(data: data, contentType: imageType)))
                    lock.unlock()
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    defer { group.leave() }
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          let uti = UTType(filenameExtension: url.pathExtension),
                          uti.conforms(to: .image),
                          let fileData = try? Data(contentsOf: url) else { return }
                    lock.lock()
                    results.append((index, Imported(data: fileData, contentType: uti.identifier)))
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            let ordered = results.sorted { $0.0 < $1.0 }.map(\.1)
            completion(ordered)
        }
    }

    /// Reads one image directly off `NSPasteboard.general` — PNG, then TIFF,
    /// then the first file URL that points at an image. Used by the ⌘V key
    /// monitor rather than `.onPasteCommand`, which never fires for the
    /// Attachments section (see the file-level doc comment above).
    static func importFromGeneralPasteboard() -> Imported? {
        let pasteboard = NSPasteboard.general

        if let data = pasteboard.data(forType: .png) {
            return Imported(data: data, contentType: UTType.png.identifier)
        }
        if let data = pasteboard.data(forType: .tiff) {
            return Imported(data: data, contentType: UTType.tiff.identifier)
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                guard let uti = UTType(filenameExtension: url.pathExtension),
                      uti.conforms(to: .image),
                      let data = try? Data(contentsOf: url) else { continue }
                return Imported(data: data, contentType: uti.identifier)
            }
        }
        return nil
    }

    /// Normalizes arbitrary pasted image bytes (TIFF, JPEG, whatever the
    /// pasteboard handed us) to PNG, so every pasted image ends up with the
    /// single content type `Attachment.isImage` and `NSImage(data:)` previews
    /// both expect. Returns nil if the bytes aren't a decodable image.
    static func normalizedPNG(from data: Data) -> Data? {
        guard let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// "Pasted image HH.mm.ss.png" — shared naming convention for every
    /// pasted image, whether it lands on an issue's attachments or a
    /// comment's.
    static func pastedImageFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH.mm.ss"
        return "Pasted image \(formatter.string(from: .now)).png"
    }
}
