import CloudKit
import Observation
import Foundation

/// Monitors iCloud account availability and exposes it as observable state.
/// The app remains fully functional when iCloud is unavailable — this service
/// only surfaces a banner so the user knows sync is paused.
///
/// IMPORTANT: This service only attempts to contact CKContainer when the app
/// has the required iCloud entitlement. Without it, any CKContainer call
/// hard-crashes at the OS level (_os_crash), which Swift cannot catch.
@Observable
@MainActor
final class iCloudStatus {

    enum Status {
        case available
        case unavailable(reason: String)
        case unknown
    }

    private(set) var status: Status = .unknown

    var showOfflineBanner: Bool {
        if case .unavailable = status { return true }
        return false
    }

    init() {
        // Only attempt CloudKit access if the entitlement exists.
        // Without the entitlement, CKContainer init hard-crashes the process.
        guard ContainerFactory.hasCloudKitEntitlement() else {
            // No entitlement = not configured yet. Don't show a banner;
            // the app just runs in local mode silently.
            status = .unknown
            return
        }
        Task { await refresh() }
        NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refresh() }
        }
    }

    func refresh() async {
        guard ContainerFactory.hasCloudKitEntitlement() else { return }
        do {
            let accountStatus = try await CKContainer(
                identifier: ContainerFactory.cloudKitContainerID
            ).accountStatus()
            switch accountStatus {
            case .available:
                status = .available
            case .noAccount:
                status = .unavailable(reason: "Sign into iCloud in System Settings to sync.")
            case .restricted:
                status = .unavailable(reason: "iCloud is restricted on this device.")
            case .couldNotDetermine:
                status = .unavailable(reason: "Could not reach iCloud. Check your connection.")
            case .temporarilyUnavailable:
                status = .unavailable(reason: "iCloud is temporarily unavailable.")
            @unknown default:
                status = .unavailable(reason: "iCloud status unknown.")
            }
        } catch {
            status = .unavailable(reason: "iCloud check failed: \(error.localizedDescription)")
        }
    }
}
