import Foundation
import SwiftData

/// A Linear-style comment on an Issue. Images are shared with the
/// Attachment model (see Attachment.comment) rather than a dedicated type,
/// so preview/open/remove logic doesn't need to be duplicated.
@Model
final class Comment {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date.now

    var issue: Issue? = nil

    // Sole declaration of the Comment↔Attachment inverse. Attachment.comment
    // has no @Relationship macro, mirroring Issue.attachments/Attachment.issue.
    @Relationship(deleteRule: .cascade, inverse: \Attachment.comment)
    var attachments: [Attachment]? = []

    var unwrappedAttachments: [Attachment] {
        (attachments ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    init(text: String = "") {
        self.text = text
    }
}
