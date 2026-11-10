import Foundation

/// Decides which entries inside `~/.claude/projects/<id>/` are disposable
/// session data. Everything else (notably `memory/`, which holds Claude's
/// auto-memory) is never touched by cleanup.
enum SessionCleanup {
    /// `*.jsonl` transcripts and per-session directories (named by the session
    /// UUID, holding subagent transcripts and tool results).
    static func sessionItems(in projectDir: URL, fileManager fm: FileManager = .default) -> [URL] {
        guard let entries = try? fm.contentsOfDirectory(
            at: projectDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return [] }

        return entries.filter { url in
            let name = url.lastPathComponent
            if url.pathExtension == "jsonl" { return true }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            return isDir && isSessionDirectoryName(name)
        }
    }

    static func isSessionDirectoryName(_ name: String) -> Bool {
        UUID(uuidString: name) != nil
    }

    /// Total bytes of the given items, recursing into directories.
    static func size(of items: [URL], fileManager fm: FileManager = .default) -> Int64 {
        var total: Int64 = 0
        for item in items {
            let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
            if let values = try? item.resourceValues(forKeys: keys), values.isRegularFile == true {
                total += Int64(values.fileSize ?? 0)
                continue
            }
            guard let en = fm.enumerator(at: item, includingPropertiesForKeys: Array(keys)) else { continue }
            while let url = en.nextObject() as? URL {
                if let v = try? url.resourceValues(forKeys: keys), v.isRegularFile == true {
                    total += Int64(v.fileSize ?? 0)
                }
            }
        }
        return total
    }

    /// Move the project's session data to the Trash. Returns per-item failures.
    static func trashSessions(in projectDir: URL, fileManager fm: FileManager = .default) -> [(URL, Error)] {
        var failures: [(URL, Error)] = []
        for item in sessionItems(in: projectDir, fileManager: fm) {
            do {
                try fm.trashItem(at: item, resultingItemURL: nil)
            } catch {
                failures.append((item, error))
            }
        }
        return failures
    }
}
