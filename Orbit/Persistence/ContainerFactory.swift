import Foundation
import Security
import SwiftData

/// Builds the SwiftData ModelContainer with either a CloudKit-backed store
/// or a plain local store.
///
/// CloudKit is ONLY used when the app has the required entitlement configured
/// in Xcode (Signing & Capabilities → iCloud → CloudKit). Without that
/// entitlement, CloudKit initialization hard-crashes at the OS level — it
/// cannot be caught by Swift error handling.
///
/// To test CloudKit after adding the capability, do NOT pass any flag;
/// ContainerFactory will detect the entitlement automatically.
/// To force local-only (e.g. for unit tests), add: -OrbitLocalStore YES
enum ContainerFactory {

    // CloudKit container identifier — must match the one created in
    // Signing & Capabilities → iCloud → CloudKit Containers.
    static let cloudKitContainerID = "iCloud.com.fran.orbit"

    /// All five model types that form the Orbit schema.
    static let schema = Schema([
        Workspace.self,
        Project.self,
        Issue.self,
        Label.self,
        SavedView.self,
        Attachment.self,
    ])

    /// Returns a ModelContainer. Uses CloudKit only when:
    ///   1. The app's entitlement for iCloud containers is present (set in Xcode)
    ///   2. The -OrbitLocalStore YES launch argument is NOT set
    static func make() -> ModelContainer {
        let useCloudKit = hasCloudKitEntitlement() && !isLocalStoreFlagSet()

        // CRITICAL: use a DEDICATED store file at a unique path. The SwiftData
        // default (~/Library/Application Support/default.store) is SHARED by
        // every unsandboxed SwiftData app on the machine — another app writing
        // its own "default.store" silently overwrites Orbit's data. Pin Orbit
        // to its own folder so nothing else can collide with it.
        let storeURL = dedicatedStoreURL()

        let config: ModelConfiguration
        if useCloudKit {
            config = ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            config = ModelConfiguration(schema: schema, url: storeURL)
        }

        // At this point ModelContainer init can throw Swift errors (schema
        // mismatches, migration issues) — those we CAN catch and recover from.
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            assertionFailure("ModelContainer init failed: \(error). Retrying local-only at the dedicated path.")
            let fallback = ModelConfiguration(schema: schema, url: storeURL)
            container = try! ModelContainer(for: schema, configurations: [fallback])
        }
        // Enable undo/redo on the main context. SwiftData auto-registers
        // every insert/update/delete with this UndoManager, so ⌘Z works
        // for renames, deletes, attachment removals, label changes, etc.
        Task { @MainActor in
            container.mainContext.undoManager = UndoManager()
        }
        return container
    }

    /// True when the app has the iCloud container identifiers entitlement.
    /// Without this entitlement, any CKContainer call hard-crashes at the OS
    /// level — it cannot be caught by Swift do/catch.
    static func hasCloudKitEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let key = "com.apple.developer.icloud-container-identifiers" as CFString
        let value = SecTaskCopyValueForEntitlement(task, key, nil)
        return value != nil
    }

    // MARK: - Private

    /// Dedicated, Orbit-only store path:
    /// ~/Library/Application Support/Orbit/Orbit.store
    /// Created if missing. Never collides with other apps' default.store.
    static func dedicatedStoreURL() -> URL {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Orbit", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("Orbit.store")
    }

    private static func isLocalStoreFlagSet() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-OrbitLocalStore"),
              args.indices.contains(idx + 1) else { return false }
        return args[idx + 1].lowercased() == "yes"
    }
}
