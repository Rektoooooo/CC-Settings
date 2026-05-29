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
    /// Per-directory content signature (sorted name+mtime+size) so adds/removes/edits
    /// inside watched dirs (commands, skills, themes, projects, …) trigger a reload.
    private var dirSignatures: [String: String] = [:]

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

    /// Returns true if any watched config file OR directory changed on disk since the
    /// last snapshot. Covers the core files plus ~/.claude.json (MCP), stats-cache,
    /// and the catalog/content dirs (commands, skills, themes, projects, …) so the
    /// app stops swallowing every change that isn't settings.json/CLAUDE.md.
    private func hasFilesChanged() -> Bool {
        let manager = ConfigurationManager.shared
        var changed = false

        for url in manager.changeWatchFiles {
            let path = url.path
            guard let current = snapshotFile(at: path) else {
                if fileSnapshots[path] != nil {
                    fileSnapshots.removeValue(forKey: path)
                    changed = true
                }
                continue
            }
            if let previous = fileSnapshots[path] {
                if current != previous { fileSnapshots[path] = current; changed = true }
            } else {
                fileSnapshots[path] = current
                changed = true
            }
        }

        for url in manager.changeWatchDirs {
            let path = url.path
            let current = directorySignature(at: path)
            if let previous = dirSignatures[path] {
                if current != previous { dirSignatures[path] = current; changed = true }
            } else {
                dirSignatures[path] = current
                changed = true
            }
        }

        return changed
    }

    /// A cheap signature of a directory's immediate contents (sorted name|mtime|size).
    /// Changes when a file is added, removed, or modified. Empty string if missing.
    private func directorySignature(at path: String) -> String {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return "" }
        return entries.sorted().map { name -> String in
            let full = (path as NSString).appendingPathComponent(name)
            let attrs = try? fm.attributesOfItem(atPath: full)
            let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let size = (attrs?[.size] as? Int) ?? 0
            return "\(name)|\(mtime)|\(size)"
        }.joined(separator: ";")
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

                manager.loadAll(force: true)

                // Refresh watched project paths in case new projects appeared
                let projects = manager.loadProjects()
                FileWatcher.shared.updateProjectPaths(projects)

                // Notify views that hold their own @State (MCP, sessions, stats, git,
                // themes, profiles, storage badges) so they re-run their loaders.
                manager.externalChangeToken &+= 1
            }
        }
    }

    // Cleanup is handled by stopWatching() called from AppDelegate.applicationWillTerminate
}
