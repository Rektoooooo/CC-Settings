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

    /// Merges the app's encoded config onto the file's current contents and writes it.
    /// Nested objects (display, colors, gitStatus, ...) are merged key by key, so unknown
    /// nested keys written by the plugin survive; unknown top-level keys survive too.
    static func save(encodedConfig: Data, to url: URL) throws {
        var existing = try readExisting(at: url)
        guard let configJSON = try JSONSerialization.jsonObject(with: encodedConfig) as? [String: Any] else { return }

        merge(configJSON, into: &existing)

        // Strip empty/whitespace-only strings from display that the plugin would misinterpret as overrides
        if var display = existing["display"] as? [String: Any] {
            for key in ["modelOverride", "customLine"] {
                if let v = display[key] as? String, v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    display.removeValue(forKey: key)
                }
            }
            existing["display"] = display
        }

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let output = try JSONSerialization.data(withJSONObject: existing, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try output.write(to: url, options: .atomic)
    }

    private static func merge(_ new: [String: Any], into target: inout [String: Any]) {
        for (key, value) in new {
            if let newDict = value as? [String: Any], var existingDict = target[key] as? [String: Any],
               key != "customColors" {
                merge(newDict, into: &existingDict)
                target[key] = existingDict
            } else {
                target[key] = value
            }
        }
    }
}
