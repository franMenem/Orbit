import Foundation
import SwiftData
import os

/// Orquesta la sincronización con la API local: importa la bandeja (al
/// arrancar, al activarse la app y en vivo con un watcher), y mantiene el
/// snapshot `Export/issues.json` al día (tras cada import y tras cualquier
/// save de la UI, con debounce).
final class InboxSync {
    static let logger = Logger(subsystem: "com.fran.Orbit", category: "InboxSync")

    /// Instancia compartida de la app (Inbox y Export reales).
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

    /// Punto de entrada de la UI: no hace nada bajo XCTest (no tocar Inbox/Export/store reales).
    func startFromUI(context: ModelContext) {
        guard !InboxImporter.isRunningUnderTests else { return }
        start(context: context)
    }

    /// Idempotente: la segunda llamada solo reintenta el import.
    func start(context: ModelContext) {
        guard self.context == nil else { importNow(); return }
        self.context = context

        // Export al arrancar (antes del import: Python ya puede leer algo).
        exporter.export(from: context)

        // Cualquier save (UI o import) → export con debounce ~1 s.
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleExport() }
        }

        // Live import: el watcher crea el Inbox si no existe.
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

    /// Trigger de launch / .active / watcher. El guard `isImporting` vive en el importer.
    func importNow() {
        guard let context else { return }
        let summary = importer.importPending(into: context)
        if summary.imported + summary.updated + summary.deleted + summary.duplicates + summary.failed > 0 {
            Self.logger.notice("Import: \(summary.imported) creadas, \(summary.updated) actualizadas, \(summary.deleted) borradas, \(summary.failed) fallidas")
        }
        exporter.export(from: context)   // si no cambió nada, no reescribe
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
