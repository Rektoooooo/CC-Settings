import Foundation

/// How Claude Code picks project instruction files (the built-in `cc-plugin-agents-md`
/// plugin's `instructionFiles` option, verified against the 2.1.322 binary).
enum InstructionFilesMode: String, CaseIterable, Identifiable {
    case claudeMd = "claude-md"
    case claudeMdOrAgentsMd = "claude-md-or-agents-md"
    case claudeMdAndAgentsMd = "claude-md-and-agents-md"
    case managedOnly = "managed-only"

    var id: String { rawValue }

    /// The CLI default when nothing is configured.
    static let `default`: InstructionFilesMode = .claudeMdOrAgentsMd

    var displayName: String {
        switch self {
        case .claudeMd: return "CLAUDE.md only"
        case .claudeMdOrAgentsMd: return "CLAUDE.md, or AGENTS.md when absent"
        case .claudeMdAndAgentsMd: return "CLAUDE.md and AGENTS.md"
        case .managedOnly: return "Managed instructions only"
        }
    }

    /// The pre-rename `projectInstructions` values the CLI still reads.
    static func fromLegacy(_ value: String) -> InstructionFilesMode? {
        switch value {
        case "none": return .managedOnly
        case "claude": return .claudeMd
        case "agents-fallback": return .claudeMdOrAgentsMd
        case "both": return .claudeMdAndAgentsMd
        default: return nil
        }
    }
}

/// Validation for the `attributionProject` setting.
enum AttributionProjectID {
    /// Returns the trimmed id when it is one the CLI accepts: `claude_proj_…`, `chan_…`
    /// (a non-empty id after the prefix, no whitespace) or the UUID of a `claude_proj_` Project.
    static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        for prefix in ["claude_proj_", "chan_"] where trimmed.hasPrefix(prefix) {
            return trimmed.count > prefix.count ? trimmed : nil
        }
        return UUID(uuidString: trimmed) != nil ? trimmed : nil
    }
}

extension ConfigurationManager {
    /// Built-in plugin id for the AGENTS.md plugin. Contains `@` and `-`, so it must stay ONE
    /// path segment: it is addressed through `applyEdits` path arrays, never a dotted string.
    static let agentsMdPluginId = "cc-plugin-agents-md@builtin"
    /// The pre-rename id the CLI also reads.
    static let agentsMdLegacyPluginId = "agents-md@builtin"

    // MARK: - Flags

    /// Keys whose CLI default is true (`idleCompaction`, `switchModelsOnFlag`, `syncClaudeAi*`):
    /// on removes the key, off writes `false`.
    func saveDefaultOnFlag(_ key: String, enabled: Bool) {
        applyEdits([(path: [key], value: enabled ? nil : false)])
    }

    /// Keys whose CLI default is false (`permissions.denyInsteadOfPrompting`, …): on writes
    /// `true`, off removes the key.
    func saveDefaultOffFlag(_ path: [String], enabled: Bool) {
        applyEdits([(path: path, value: enabled ? true : nil)])
    }

    /// Tri-state: nil removes the key (CLI default), otherwise the explicit boolean.
    func saveTriStateFlag(_ key: String, value: Bool?) {
        applyEdits([(path: [key], value: value)])
    }

    // MARK: - maxProseWidth / attributionProject

    /// Claude Code requires an integer >= 40. Empty clears the key. Returns false (and
    /// writes nothing) for an invalid entry.
    @discardableResult
    func saveMaxProseWidth(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { applyEdits([(path: ["maxProseWidth"], value: nil)]); return true }
        guard let parsed = Int(trimmed), parsed >= 40 else { return false }
        applyEdits([(path: ["maxProseWidth"], value: parsed)])
        return true
    }

    /// Empty clears the key; otherwise the id must pass `AttributionProjectID`. Returns false
    /// (and writes nothing) for an invalid id.
    @discardableResult
    func saveAttributionProject(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { applyEdits([(path: ["attributionProject"], value: nil)]); return true }
        guard let id = AttributionProjectID.normalized(trimmed) else { return false }
        applyEdits([(path: ["attributionProject"], value: id)])
        return true
    }

    // MARK: - permissions.* flags (read raw: the permissions struct is all-or-nothing)

    func permissionFlag(_ key: String, in raw: [String: Any]? = nil) -> Bool {
        let root = raw ?? rawSettingsObject()
        return ((root["permissions"] as? [String: Any])?[key] as? Bool) ?? false
    }

    // MARK: - instructionFiles

    /// Pure read: `instructionFiles` wins; the legacy `projectInstructions` is used only when
    /// it is absent; an unrecognised value reads as the default (as the CLI does).
    static func readInstructionFiles(in raw: [String: Any]) -> InstructionFilesMode {
        let configs = raw["pluginConfigs"] as? [String: Any]
        for id in [agentsMdPluginId, agentsMdLegacyPluginId] {
            let options = (configs?[id] as? [String: Any])?["options"] as? [String: Any]
            if let value = options?["instructionFiles"] as? String {
                return InstructionFilesMode(rawValue: value) ?? .default
            }
            if let legacy = options?["projectInstructions"] as? String {
                return InstructionFilesMode.fromLegacy(legacy) ?? .claudeMd
            }
        }
        return .default
    }

    func readInstructionFiles() -> InstructionFilesMode {
        Self.readInstructionFiles(in: rawSettingsObject())
    }

    /// Writes only `pluginConfigs["cc-plugin-agents-md@builtin"].options.instructionFiles`.
    /// The default removes the key (and prunes emptied parents) unless a legacy
    /// `projectInstructions` is present, which would otherwise apply again.
    func saveInstructionFiles(_ mode: InstructionFilesMode) {
        let raw = rawSettingsObject()
        let configs = raw["pluginConfigs"] as? [String: Any]
        let hasLegacy = [Self.agentsMdPluginId, Self.agentsMdLegacyPluginId].contains { id in
            ((configs?[id] as? [String: Any])?["options"] as? [String: Any])?["projectInstructions"] != nil
        }
        let value: Any? = (mode == .default && !hasLegacy) ? nil : mode.rawValue
        applyEdits([(path: ["pluginConfigs", Self.agentsMdPluginId, "options", "instructionFiles"], value: value)])
    }
}

// MARK: - Hook definition fields

/// Hook keys that live in `HookDefinition.extra`. Verified against the 2.1.322 schema:
/// `statusMessage` / `once` exist on every hook type; `async` and `onFailure` only on
/// command hooks (`onFailure` also on http); `onFailure` is ignored for async hooks.
extension HookDefinition {
    var statusMessage: String? {
        get { extra["statusMessage"]?.stringValue }
        set { extra["statusMessage"] = newValue.map { JSONValue.string($0) } }
    }

    var once: Bool? {
        get { if case .bool(let b)? = extra["once"] { return b }; return nil }
        set { extra["once"] = newValue.map { JSONValue.bool($0) } }
    }

    var runsAsync: Bool? {
        get { if case .bool(let b)? = extra["async"] { return b }; return nil }
        set { extra["async"] = newValue.map { JSONValue.bool($0) } }
    }

    /// "continue" (CLI default) or "block".
    var onFailure: String? {
        get { extra["onFailure"]?.stringValue }
        set { extra["onFailure"] = newValue.map { JSONValue.string($0) } }
    }
}
