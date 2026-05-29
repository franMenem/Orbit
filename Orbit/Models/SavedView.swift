import Foundation
import SwiftData

// Stub registered from day 1 so the schema/container is stable.
// Phase 3 (plan 03-02) fills in filter/sort fields.
@Model
final class SavedView {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now

    var workspace: Workspace? = nil

    init(name: String = "") {
        self.name = name
    }
}
