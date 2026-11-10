import Foundation

/// Read-modify-write for the claude-hud plugin's `config.json`.
enum HUDConfigFile {
    enum Failure: LocalizedError {
        case unreadable(URL)
        case malformed(URL)

        var errorDescription: String? {
            switch self {
            case .unreadable(let url): return "Could not read \(url.path). Nothing was written."
            case .malformed(let url): return "\(url.path) is not valid JSON. Fix or delete it; CC Settings did not overwrite it."
            }
        }
    }

    /// Reads the existing file. Returns `[:]` when it doesn't exist; throws when it exists
    /// but can't be read or parsed (callers must then NOT write).
    static func readExisting(at url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        guard let data = try? Data(contentsOf: url) else { throw Failure.unreadable(url) }
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return [:] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.malformed(url)
        }
        return json
    }

    typealias Edit = (path: [String], value: Any?)

    /// Writes the app's whole encoded config. Only meant for creating a file; screens that
    /// edit an existing config use `diff` + `saveEdits` so they never write keys the user
    /// did not change.
    static func save(encodedConfig: Data, to url: URL) throws {
        let configJSON = try JSONSerialization.jsonObject(with: encodedConfig) as? [String: Any] ?? [:]
        try saveEdits(diff(from: [:], to: configJSON), to: url)
    }

    /// Leaf key paths of a JSON object (arrays and scalars are leaves).
    static func flatten(_ json: [String: Any], prefix: [String] = []) -> [[String]: Any] {
        var result: [[String]: Any] = [:]
        for (key, value) in json {
            if let nested = value as? [String: Any] {
                result.merge(flatten(nested, prefix: prefix + [key])) { $1 }
            } else {
                result[prefix + [key]] = value
            }
        }
        return result
    }

    /// Key paths whose value differs between `old` and `new` (removed paths get a nil value).
    static func diff(from old: [String: Any], to new: [String: Any]) -> [Edit] {
        let before = flatten(old)
        let after = flatten(new)
        var edits: [Edit] = []
        for (path, value) in after {
            if let previous = before[path], (previous as AnyObject).isEqual(value) { continue }
            edits.append((path: path, value: value))
        }
        for path in before.keys where after[path] == nil {
            edits.append((path: path, value: nil))
        }
        return edits.sorted { $0.path.joined(separator: "\u{1F}") < $1.path.joined(separator: "\u{1F}") }
    }

    /// Re-reads the file now, applies only `edits`, and writes it back. Every other key, known
    /// or not, keeps whatever value is on disk at this moment (so an edit made by the plugin
    /// or by hand after this screen loaded is not clobbered).
    static func saveEdits(_ edits: [Edit], to url: URL) throws {
        var existing = try readExisting(at: url)
        for edit in edits {
            // Blank overrides would be read by the plugin as real (empty) overrides.
            var value = edit.value
            if edit.path == ["display", "modelOverride"] || edit.path == ["display", "customLine"],
               let s = value as? String, s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                value = nil
            }
            set(&existing, path: edit.path[...], value: value)
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let output = try JSONSerialization.data(withJSONObject: existing, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try output.writeAtomicallyFollowingSymlinks(to: url)
    }

    private static func set(_ dict: inout [String: Any], path: ArraySlice<String>, value: Any?) {
        guard let first = path.first else { return }
        if path.count == 1 {
            if let value { dict[first] = value } else { dict.removeValue(forKey: first) }
            return
        }
        var nested = dict[first] as? [String: Any] ?? [:]
        if value == nil, dict[first] as? [String: Any] == nil { return }
        set(&nested, path: path.dropFirst(), value: value)
        dict[first] = nested
    }
}
