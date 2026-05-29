import Foundation
import SwiftData

/// Builds the SwiftData ModelContainer with either a CloudKit-backed store
/// or a plain local store (for unit tests / running without an iCloud account).
///
/// Usage:
///   .modelContainer(ContainerFactory.make())
///
/// To force local-only during development, add the launch argument:
///   -OrbitLocalStore YES
/// or set the compile-time flag ORBIT_LOCAL_STORE=1 in your scheme.
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
    ])

    /// Returns a ModelContainer. Defaults to CloudKit unless:
    ///   • The `-OrbitLocalStore YES` launch argument is present, OR
    ///   • `useCloudKit` is explicitly passed as false.
    static func make(useCloudKit: Bool? = nil) -> ModelContainer {
        let wantsCloud = useCloudKit ?? !isLocalStoreFlagSet()

        let config: ModelConfiguration
        if wantsCloud {
            config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            // Local-only — useful for testing without an iCloud account.
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If CloudKit config fails (e.g. capabilities not yet added),
            // fall back gracefully to a local store rather than hard-crashing.
            // The iCloudStatus service will surface the offline state to the user.
            assertionFailure("Primary container failed: \(error). Falling back to local store.")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    // MARK: - Private

    /// True when the `-OrbitLocalStore YES` launch argument was passed.
    private static func isLocalStoreFlagSet() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-OrbitLocalStore"),
           args.indices.contains(idx + 1),
           args[idx + 1].lowercased() == "yes" {
            return true
        }
        return false
    }
}
