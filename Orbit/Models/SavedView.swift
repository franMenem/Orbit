import Foundation
import SwiftData

/// Phase 3 extends the Phase 1 stub with serialized filter fields.
/// All new properties are defaulted — additive, CloudKit-safe migration.
/// Workspace inverse + container registration already exist from Phase 1.
@Model
final class SavedView {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now

    // Serialized filter config (added Phase 3)
    var statusesRaw: [String] = []
    var prioritiesRaw: [Int] = []
    var labelIDsRaw: [String] = []
    var searchText: String = ""
    var sortRaw: String = ""

    var workspace: Workspace? = nil

    init(name: String = "") {
        self.name = name
    }
}
