import Foundation

/// Effort-level storage rules, verified against the Claude Code 2.1.322 binary.
///
/// - Top-level `effortLevel` accepts only low/medium/high/xhigh; `max` and `ultracode` are
///   silently dropped by the CLI's schema (`.catch(undefined)`).
/// - In user scope it is only a legacy fallback. `/effort` persists to
///   `modelSettings.<canonicalModelId>.effortLevel`, which the 5.5 generation reads instead.
/// - `maxEffortLevel` (low..max) is a cap, valid in any scope; the lowest value wins.
enum EffortLevels {
    /// Values the picker may write.
    static let selectable = ["low", "medium", "high", "xhigh"]
    /// Values `maxEffortLevel` accepts.
    static let cap = ["low", "medium", "high", "xhigh", "max"]
}

struct EffortReading: Equatable {
    /// The level that applies to the model, nil when none is set (or none applies).
    var value: String?
    /// A top-level `effortLevel` the CLI would ignore (e.g. `max`, `ultracode`), if present.
    var invalidTopLevel: String?
    /// True when `value` came from `modelSettings.<model>`; false for the top-level fallback.
    var isPerModel: Bool
    /// True when the model reads `modelSettings`, so a top-level value would not apply.
    var modelIgnoresTopLevel: Bool
}

extension ConfigurationManager {
    /// Current on-disk user settings as a raw object (unknown keys included).
    func rawSettingsObject() -> [String: Any] {
        (try? readJSONObjectForWrite(at: settingsURL)) ?? [:]
    }

    /// Pure read helper so the rules can be unit-tested without a manager.
    static func readEffort(in raw: [String: Any], model: String) -> EffortReading {
        let canon = canonicalModelId(model)
        let top = raw["effortLevel"] as? String
        let invalid = (top != nil && !EffortLevels.selectable.contains(top!)) ? top : nil
        let validTop = (top != nil && invalid == nil) ? top : nil

        if !canon.isEmpty {
            let entry = (raw["modelSettings"] as? [String: Any])?[canon] as? [String: Any]
            if let level = entry?["effortLevel"] as? String {
                return EffortReading(value: level, invalidTopLevel: invalid, isPerModel: true,
                                     modelIgnoresTopLevel: !usesLegacyTopLevelEffort(canonicalId: canon))
            }
            if !usesLegacyTopLevelEffort(canonicalId: canon) {
                return EffortReading(value: nil, invalidTopLevel: invalid, isPerModel: false, modelIgnoresTopLevel: true)
            }
        }
        return EffortReading(value: validTop, invalidTopLevel: invalid, isPerModel: false, modelIgnoresTopLevel: false)
    }

    func readEffort(forModel model: String) -> EffortReading {
        Self.readEffort(in: rawSettingsObject(), model: model)
    }

    /// Writes the effort for `model`. A 5.5-generation model (any model that
    /// reads `modelSettings`) is written to
    /// `modelSettings.<id>.effortLevel`; legacy models and an unset model use the top-level key.
    /// nil removes the value.
    func saveEffortLevel(_ level: String?, forModel model: String) {
        let canon = canonicalModelId(model)
        if canon.isEmpty || usesLegacyTopLevelEffort(canonicalId: canon) {
            applyEdits([(path: ["effortLevel"], value: level)])
        } else {
            applyEdits([(path: ["modelSettings", canon, "effortLevel"], value: level)])
        }
    }

    /// Clears a top-level `effortLevel` the CLI would ignore.
    func clearTopLevelEffort() {
        applyEdits([(path: ["effortLevel"], value: nil)])
    }

    /// Sets or (nil) removes the top-level `maxEffortLevel` cap.
    func saveMaxEffortLevel(_ level: String?, to url: URL? = nil) {
        applyEdits([(path: ["maxEffortLevel"], value: level)], to: url)
    }
}
