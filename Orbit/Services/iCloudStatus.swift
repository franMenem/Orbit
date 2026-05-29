import CloudKit
import Observation
import Foundation

/// Monitors iCloud account availability and exposes it as observable state.
/// The app remains fully functional when iCloud is unavailable — this service
/// only surfaces a banner so the user knows sync is paused.
@Observable
@MainActor
final class iCloudStatus {

    enum Status {
        /// CKAccountStatus was checked and the account is available.
        case available
        /// iCloud is not configured, restricted, or temporarily unreachable.
        case unavailable(reason: String)
        /// Check hasn't completed yet.
        case unknown
    }

    private(set) var status: Status = .unknown

    /// True when a non-blocking "Working offline" banner should be shown.
    var showOfflineBanner: Bool {
        if case .unavailable = status { return true }
        return false
    }

    init() {
        Task { await refresh() }
        // Re-check whenever the app comes back to the foreground.
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
