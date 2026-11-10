import Foundation

/// Maps Claude Code's encoded project folder names (`~/.claude/projects/<id>`)
/// back to real filesystem paths without guessing.
///
/// Claude Code encodes a path by replacing every character that is not
/// `[a-zA-Z0-9]` with `-`; encodings longer than 200 characters are truncated
/// and get a hash suffix. The encoding is lossy, so the real path is recovered
/// from sources that hold it verbatim: the `projects` keys in `~/.claude.json`,
/// then the `cwd` recorded inside the project's session transcripts.
enum ProjectPathResolver {
    /// Sentinel root for projects whose path could not be determined. It can
    /// never be created or written to (`/dev/null` is not a directory), so code
    /// that blindly builds `<originalPath>/.claude/...` fails instead of
    /// materialising directories under a guessed location.
    static let unresolvedPrefix = "/dev/null/unresolved-project/"

    static func unresolvedPath(for id: String) -> String { unresolvedPrefix + id }
    static func isResolved(_ path: String) -> Bool { !path.hasPrefix(unresolvedPrefix) }

    private static let maxEncodedLength = 200

    /// Claude Code's encoding. JS regex replacement works on UTF-16 code units,
    /// so characters outside the BMP become two dashes.
    static func encode(_ path: String) -> String {
        let mapped = path.utf16.map { unit -> UInt16 in
            switch unit {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: return unit
            default: return 0x2D
            }
        }
        return String(decoding: mapped, as: UTF16.self)
    }

    /// True when `id` is the folder name Claude Code would use for `path`.
    /// Over-long names carry a hash we don't reproduce, so only the first 200
    /// characters are compared for those.
    static func idMatches(_ id: String, path: String) -> Bool {
        let encoded = encode(path)
        if id == encoded { return true }
        if id.count > maxEncodedLength, encoded.count > maxEncodedLength {
            return id.prefix(maxEncodedLength) == encoded.prefix(maxEncodedLength)
        }
        return false
    }

    /// Resolve `id` to a real path, or nil when no authoritative source knows it.
    static func resolve(id: String, projectDir: URL, knownProjectPaths: [String], fileManager fm: FileManager = .default) -> String? {
        let candidates = knownProjectPaths.filter { idMatches(id, path: $0) }
        if let existing = candidates.first(where: { fm.fileExists(atPath: $0) }) { return existing }
        if let first = candidates.first { return first }
        return cwdFromNewestSession(id: id, projectDir: projectDir, fileManager: fm)
    }

    /// The `cwd` recorded in the newest transcript, accepted only if it encodes
    /// back to this project's folder name.
    static func cwdFromNewestSession(id: String, projectDir: URL, fileManager fm: FileManager = .default) -> String? {
        guard let files = try? fm.contentsOfDirectory(
            at: projectDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        let sessions = files
            .filter { $0.pathExtension == "jsonl" }
            .map { ($0, (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast) }
            .sorted { $0.1 > $1.1 }

        for (file, _) in sessions.prefix(3) {
            if let cwd = firstMatchingCwd(in: file, id: id) { return cwd }
        }
        return nil
    }

    private static func firstMatchingCwd(in file: URL, id: String) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 512 * 1024), !data.isEmpty else { return nil }

        for line in data.split(separator: 0x0A) {
            // Cheap pre-check before paying for a JSON parse.
            guard line.range(of: Data("\"cwd\"".utf8)) != nil,
                  let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let cwd = obj["cwd"] as? String, cwd.hasPrefix("/"),
                  idMatches(id, path: cwd) else { continue }
            return cwd
        }
        return nil
    }
}
