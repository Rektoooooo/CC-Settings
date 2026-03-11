import Foundation
import CoreServices

@MainActor
class FileWatcher: ObservableObject {
    static let shared = FileWatcher()

    private var stream: FSEventStreamRef?
    private var debounceTimer: Timer?
    private let globalWatchPath: String
    private var watchPaths: [String] = []

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

    // MARK: - Private

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
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self != nil else { return }
                let manager = ConfigurationManager.shared
                // Skip reload if the app itself just saved (avoids overwriting in-progress edits)
                if Date().timeIntervalSince(manager.lastSaveTime) < 1.0 {
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
