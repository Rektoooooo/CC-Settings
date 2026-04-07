import Foundation
import CoreServices

@MainActor
class FileWatcher: ObservableObject {
    static let shared = FileWatcher()

    private var stream: FSEventStreamRef?
    private var debounceTimer: Timer?
    private let globalWatchPath: String
    private var watchPaths: [String] = []

    /// Per-file mtime+size tracking to skip reloads when nothing actually changed on disk.
    private var fileSnapshots: [String: FileSnapshot] = [:]

    private struct FileSnapshot: Equatable {
        let mtime: Date
        let size: Int
    }

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        globalWatchPath = home.appendingPathComponent(".claude").path
        watchPaths = [globalWatchPath]
    }

    func startWatching() {
        guard stream == nil else { return }
        createStream()
    }

    func stopWatching() {
        destroyStream()
        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    /// Updates the set of project paths to watch and restarts the FSEvents stream if needed.
    /// Call this after projects are discovered or refreshed.
    func updateProjectPaths(_ projects: [Project]) {
        let fm = FileManager.default
        var paths: [String] = [globalWatchPath]

        for project in projects {
            let projectClaudeDir = (project.originalPath as NSString).appendingPathComponent(".claude")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: projectClaudeDir, isDirectory: &isDir), isDir.boolValue {
                paths.append(projectClaudeDir)
            }

            // Watch the project root for .mcp.json changes
            if fm.fileExists(atPath: project.originalPath, isDirectory: &isDir), isDir.boolValue {
                paths.append(project.originalPath)
            }
        }

        // Deduplicate and sort for stable comparison
        let newPaths = Array(Set(paths)).sorted()
        let oldPaths = watchPaths.sorted()

        guard newPaths != oldPaths else { return }

        watchPaths = newPaths
        // Restart the stream with updated paths
        if stream != nil {
            destroyStream()
            createStream()
        }
    }

    /// Called by ConfigurationManager after a successful save so the next FSEvent
    /// for that file is recognized as self-triggered and skipped.
    func updateFileTracking(for paths: [URL]) {
        for url in paths {
            if let snapshot = snapshotFile(at: url.path) {
                fileSnapshots[url.path] = snapshot
            }
        }
    }

    // MARK: - Private

    private func snapshotFile(at path: String) -> FileSnapshot? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mtime = attrs[.modificationDate] as? Date,
              let size = attrs[.size] as? Int else {
            return nil
        }
        return FileSnapshot(mtime: mtime, size: size)
    }

    /// Returns true if any of the managed config files changed on disk since last snapshot.
    private func hasFilesChanged() -> Bool {
        let manager = ConfigurationManager.shared
        let trackedPaths = [
            manager.settingsURL.path,
            manager.localSettingsURL.path,
            manager.claudeMDURL.path,
        ]

        for path in trackedPaths {
            guard let current = snapshotFile(at: path) else {
                // File doesn't exist — changed if we had a previous snapshot
                if fileSnapshots[path] != nil {
                    fileSnapshots.removeValue(forKey: path)
                    return true
                }
                continue
            }

            if let previous = fileSnapshots[path] {
                if current != previous {
                    fileSnapshots[path] = current
                    return true
                }
            } else {
                // First time seeing this file
                fileSnapshots[path] = current
                return true
            }
        }

        return false
    }

    private func createStream() {
        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        let paths = watchPaths as CFArray
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

    private func destroyStream() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    private func handleEvents() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self != nil else { return }
                let manager = ConfigurationManager.shared

                // Secondary guard: skip if the app itself just saved
                if Date().timeIntervalSince(manager.lastSaveTime) < 1.0 {
                    return
                }

                // Primary guard: skip if no managed files actually changed on disk
                guard FileWatcher.shared.hasFilesChanged() else {
                    return
                }

                manager.loadAll()

                // Refresh watched project paths in case new projects appeared
                let projects = manager.loadProjects()
                FileWatcher.shared.updateProjectPaths(projects)
            }
        }
    }

    // Cleanup is handled by stopWatching() called from AppDelegate.applicationWillTerminate
}
