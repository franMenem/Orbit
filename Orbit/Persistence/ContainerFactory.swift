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

        let config: ModelConfiguration
        if useCloudKit {
            config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            config = ModelConfiguration(schema: schema)
        }

        // At this point ModelContainer init can throw Swift errors (schema
        // mismatches, migration issues) — those we CAN catch and recover from.
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            assertionFailure("ModelContainer init failed: \(error). Retrying with local store.")
            let fallback = ModelConfiguration(schema: schema)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
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

    private static func isLocalStoreFlagSet() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-OrbitLocalStore"),
              args.indices.contains(idx + 1) else { return false }
        return args[idx + 1].lowercased() == "yes"
    }
}
