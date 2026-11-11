import Foundation
import SwiftData
import os

/// Orchestrates synchronization with the local API: imports the inbox (on
/// launch, when the app becomes active and live via a watcher), and keeps the
/// `Export/issues.json` snapshot up to date (after each import and after any
/// UI save, with debounce).
final class InboxSync {
    static let logger = Logger(subsystem: "com.fran.Orbit", category: "InboxSync")

    /// Shared app instance (real Inbox and Export).
    static let shared = InboxSync()

    let importer: InboxImporter
    let exporter: IssueSnapshotExporter
    private let exportDebounce: Duration
    private let watchDebounce: TimeInterval

    private var context: ModelContext?
    private var watcher: InboxWatcher?
    private var saveObserver: NSObjectProtocol?
    private var exportTask: Task<Void, Never>?

    init(importer: InboxImporter = InboxImporter(),
         exporter: IssueSnapshotExporter = IssueSnapshotExporter(),
         exportDebounce: Duration = .seconds(1),
         watchDebounce: TimeInterval = 0.4) {
        self.importer = importer
        self.exporter = exporter
        self.exportDebounce = exportDebounce
        self.watchDebounce = watchDebounce
    }

    /// UI entry point: does nothing under XCTest (don't touch the real Inbox/Export/store).
    func startFromUI(context: ModelContext) {
        guard !InboxImporter.isRunningUnderTests else { return }
        start(context: context)
    }

    /// Idempotent: the second call only retries the import.
    func start(context: ModelContext) {
        guard self.context == nil else { importNow(); return }
        self.context = context

        // Export on launch (before the import: Python can already read something).
        exporter.export(from: context)

        // Any save (UI or import) → export with ~1 s debounce.
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleExport() }
        }

        // Live import: the watcher creates the Inbox if it doesn't exist.
        let w = InboxWatcher(directory: importer.inboxURL, debounce: watchDebounce) { [weak self] in
            self?.importNow()
        }
        w.start()
        watcher = w

        importNow()
    }

    func stop() {
        watcher?.stop(); watcher = nil
        exportTask?.cancel(); exportTask = nil
        if let saveObserver { NotificationCenter.default.removeObserver(saveObserver) }
        saveObserver = nil
        context = nil
    }

    /// Trigger from launch / .active / watcher. The `isImporting` guard lives in the importer.
    func importNow() {
        guard let context else { return }
        let summary = importer.importPending(into: context)
        if summary.imported + summary.updated + summary.deleted + summary.duplicates + summary.failed > 0 {
            Self.logger.notice("Import: \(summary.imported) created, \(summary.updated) updated, \(summary.deleted) deleted, \(summary.failed) failed")
        }
        exporter.export(from: context)   // if nothing changed, it doesn't rewrite
    }

    private func scheduleExport() {
        exportTask?.cancel()
        exportTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.exportDebounce)
            guard !Task.isCancelled, let context = self.context else { return }
            self.exporter.export(from: context)
        }
    }
}
