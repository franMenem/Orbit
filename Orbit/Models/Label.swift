import Foundation
import SwiftData

@Model
final class Label {
    var id: UUID = UUID()
    var name: String = "Label"
    var colorHex: String = "#8E8E93"
    var createdAt: Date = Date.now

    var workspace: Workspace? = nil

    // Inverse side of the Issue↔Label many-to-many.
    // @Relationship macro is intentionally omitted here — declaring inverse: on BOTH
    // sides causes an ambiguous-inverse compile error. Only Issue.labels carries it.
    var issues: [Issue]? = []

    init(name: String = "Label", colorHex: String = "#8E8E93") {
        self.name = name
        self.colorHex = colorHex
    }
}
