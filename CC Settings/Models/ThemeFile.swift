import Foundation

// MARK: - ThemeFile

/// A Claude Code custom theme: `~/.claude/themes/<slug>.json` shaped as
/// `{ "name": "...", "base": "dark", "overrides": { "<paletteKey>": "<colour>" } }`.
///
/// Claude Code only honours override keys that exist in the base palette
/// (`ClaudeThemePalette.keys`) and only colour strings it can parse, and it falls back to
/// `base: "dark"` for an unknown base. Everything this app does not model is kept verbatim
/// (`unknownFields` for top-level keys, `extraOverrides` for override entries) so a save
/// never drops data.
struct ThemeFile: Identifiable {
    let id: String        // slug = filename stem, e.g. "midnight"
    let url: URL          // ~/.claude/themes/midnight.json
    var name: String
    var base: String
    /// Override entries whose key is a palette key and whose value is a string.
    var overrides: [String: String]
    /// Override entries the editor does not model (non-palette keys, non-string values).
    var extraOverrides: [String: Any]
    /// Top-level keys other than name/base/overrides.
    var unknownFields: [String: Any]
    /// Colour keys from the flat format older builds of this app wrote (`{"accent": "#..."}`).
    /// Claude Code ignores them; they are kept until the user converts the file.
    var legacyFlatColors: [String: String]

    init(id: String, url: URL, name: String? = nil, base: String = "dark",
         overrides: [String: String] = [:], extraOverrides: [String: Any] = [:],
         unknownFields: [String: Any] = [:], legacyFlatColors: [String: String] = [:]) {
        self.id = id
        self.url = url
        self.name = name ?? id
        self.base = ClaudeThemePalette.isValidBase(base) ? base : "dark"
        self.overrides = overrides
        self.extraOverrides = extraOverrides
        self.unknownFields = unknownFields
        self.legacyFlatColors = legacyFlatColors
    }

    var needsLegacyConversion: Bool { !legacyFlatColors.isEmpty }

    /// Colour for `key`: the override if set, otherwise the base palette's value.
    func effectiveValue(for key: String) -> String? {
        overrides[key] ?? ClaudeThemePalette.value(base: base, key: key)
    }

    // MARK: - Loading

    static func load(from url: URL) -> ThemeFile? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return parse(json, id: url.deletingPathExtension().lastPathComponent, url: url)
    }

    static func parse(_ json: [String: Any], id: String, url: URL) -> ThemeFile {
        var overrides: [String: String] = [:]
        var extraOverrides: [String: Any] = [:]
        if let raw = json["overrides"] as? [String: Any] {
            for (key, value) in raw {
                if ClaudeThemePalette.keys.contains(key), let color = value as? String {
                    overrides[key] = color
                } else {
                    extraOverrides[key] = value
                }
            }
        }

        var unknown: [String: Any] = [:]
        var legacy: [String: String] = [:]
        for (key, value) in json where !["name", "base", "overrides"].contains(key) {
            if legacyFlatKeys.contains(key), let color = value as? String {
                legacy[key] = color
            } else {
                unknown[key] = value
            }
        }

        return ThemeFile(
            id: id, url: url,
            name: json["name"] as? String,
            base: (json["base"] as? String) ?? "dark",
            overrides: overrides, extraOverrides: extraOverrides,
            unknownFields: unknown, legacyFlatColors: legacy
        )
    }

    // MARK: - Saving

    func jsonObject() -> [String: Any] {
        var top = unknownFields
        for (key, value) in legacyFlatColors { top[key] = value }
        top["name"] = name
        top["base"] = base
        var merged = extraOverrides
        for (key, value) in overrides { merged[key] = value }
        top["overrides"] = merged
        return top
    }

    func serialize() throws -> Data {
        try JSONSerialization.data(withJSONObject: jsonObject(), options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    // MARK: - Legacy flat format

    /// Colour keys the previous (wrong) flat format used.
    static let legacyFlatKeys: Set<String> = [
        "background", "foreground", "cursor", "selection", "accent", "primary",
        "error", "warning", "success", "info", "muted", "secondary",
        "keyword", "string", "comment", "number", "function", "type",
        "ansiBlack", "ansiRed", "ansiGreen", "ansiYellow", "ansiBlue", "ansiMagenta", "ansiCyan", "ansiWhite",
        "ansiBrightBlack", "ansiBrightRed", "ansiBrightGreen", "ansiBrightYellow",
        "ansiBrightBlue", "ansiBrightMagenta", "ansiBrightCyan", "ansiBrightWhite",
    ]

    /// Best-effort mapping from an old flat key to the palette key with the closest meaning.
    /// Keys with no counterpart (syntax colours, the ANSI 16, cursor, background) are not
    /// mapped and stay in the file as plain top-level keys.
    static let legacyKeyMapping: [String: String] = [
        "error": "error", "warning": "warning", "success": "success",
        "muted": "subtle", "secondary": "inactive", "foreground": "text",
        "accent": "claude", "primary": "permission", "selection": "selectionBg",
        "info": "suggestion",
    ]

    /// A converted copy: mapped colours move into `overrides` (never replacing an override
    /// that is already set), the rest stay as top-level keys. Nothing is discarded.
    func convertedFromLegacy() -> ThemeFile {
        var result = self
        for (legacyKey, color) in legacyFlatColors {
            if let paletteKey = Self.legacyKeyMapping[legacyKey], result.overrides[paletteKey] == nil {
                result.overrides[paletteKey] = color
            } else {
                result.unknownFields[legacyKey] = color
            }
        }
        result.legacyFlatColors = [:]
        return result
    }

    // MARK: - Slugs and activation values

    /// Claude Code's slug rule: lowercase, runs of non-alphanumerics become `-`, trimmed.
    static func slug(from name: String) -> String {
        var slug = ""
        var pendingDash = false
        for scalar in name.lowercased().unicodeScalars {
            let isAlnum = (scalar.value >= 0x61 && scalar.value <= 0x7A) || (scalar.value >= 0x30 && scalar.value <= 0x39)
            if isAlnum {
                if pendingDash && !slug.isEmpty { slug.append("-") }
                pendingDash = false
                slug.unicodeScalars.append(scalar)
            } else {
                pendingDash = true
            }
        }
        return slug.isEmpty ? "theme" : slug
    }

    static let activationPrefix = "custom:"

    /// The value Claude Code expects in `settings.json` `theme` for a custom theme.
    static func activationValue(forSlug slug: String) -> String { activationPrefix + slug }

    static func slug(fromActivationValue value: String?) -> String? {
        guard let value, value.hasPrefix(activationPrefix) else { return nil }
        return String(value.dropFirst(activationPrefix.count))
    }
}

extension ThemeFile: Equatable {
    static func == (lhs: ThemeFile, rhs: ThemeFile) -> Bool {
        guard lhs.id == rhs.id, lhs.url == rhs.url else { return false }
        let l = try? JSONSerialization.data(withJSONObject: lhs.jsonObject(), options: [.sortedKeys])
        let r = try? JSONSerialization.data(withJSONObject: rhs.jsonObject(), options: [.sortedKeys])
        return l == r
    }
}
