import Foundation
import CoreServices

@MainActor
class FileWatcher: ObservableObject {
    static let shared = FileWatcher()

    private var stream: FSEventStreamRef?
    private var debounceTimer: Timer?
    private let watchPath: String

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        watchPath = home.appendingPathComponent(".claude").path
    }

    func startWatching() {
        guard stream == nil else { return }

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let paths = [watchPath] as CFArray
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)

        let callback: FSEventStreamCallback = { _, info, numEvents, eventPaths, _, _ in
            guard let info = info, numEvents > 0 else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in
                watcher.handleEvents()
            }
        }

        stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        )

        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }

    func stopWatching() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    private func handleEvents() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self != nil else { return }
                let manager = ConfigurationManager.shared
                // Skip reload if the app itself just saved (avoids overwriting in-progress edits)
                if Date().timeIntervalSince(manager.lastSaveTime) < 1.0 {
                    return
                }
                manager.loadAll()
            }
        }
    }

    // Cleanup is handled by stopWatching() called from AppDelegate.applicationWillTerminate
}
