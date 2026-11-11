import Foundation
import os

/// Watches a folder with a file-system `DispatchSource` and notifies (with
/// debounce) when its contents change. Creates the folder if it doesn't exist. If the
/// folder is deleted or renamed, it recreates it and re-attaches.
final class InboxWatcher {
    static let logger = Logger(subsystem: "com.fran.Orbit", category: "InboxWatcher")

    let directory: URL
    private let debounce: TimeInterval
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    init(directory: URL, debounce: TimeInterval = 0.4, onChange: @escaping () -> Void) {
        self.directory = directory
        self.debounce = debounce
        self.onChange = onChange
    }

    deinit { stop() }

    func start() {
        guard source == nil else { return }
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("Could not create \(self.directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        let fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else {
            Self.logger.error("Could not open \(self.directory.path, privacy: .public) to watch it")
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete, .link],
            queue: .main)
        src.setEventHandler { [weak self] in
            guard let self, let src = self.source else { return }
            if !src.data.isDisjoint(with: [.rename, .delete]) {
                // The folder itself was moved/deleted: re-attach to a new one.
                self.stop()
                self.start()
            }
            self.schedule()
        }
        src.setCancelHandler { close(fd) }
        source = src
        src.resume()
    }

    func stop() {
        pending?.cancel()
        pending = nil
        source?.cancel()
        source = nil
    }

    private func schedule() {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.onChange() }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: item)
    }
}
