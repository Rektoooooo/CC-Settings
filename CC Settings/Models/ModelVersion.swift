import Foundation

enum ModelFamily: String, CaseIterable, Identifiable {
    case fable = "Fable"
    case opus = "Opus"
    case sonnet = "Sonnet"
    case haiku = "Haiku"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fable: return "book.closed"
        case .opus: return "brain.head.profile"
        case .sonnet: return "sparkles"
        case .haiku: return "hare"
        }
    }

    var description: String {
        switch self {
        case .fable: return "Mythos-class model — Anthropic's most capable, built for long autonomous sessions"
        case .opus: return "Most capable model for complex tasks requiring deep reasoning"
        case .sonnet: return "Balanced performance and speed for everyday coding tasks"
        case .haiku: return "Fastest model for quick responses and simple tasks"
        }
    }
}

/// How a catalog row relates to its family's newest model.
enum ModelKind: Equatable, Hashable {
    /// The newest model of the family; exactly one per family.
    case current
    /// An older concrete model (e.g. "Opus 5") or a hidden legacy one.
    case previous
    /// A moving alias such as `opus`, `opusplan` or `opus[1m]`.
    case alias
}

struct ModelVersion: Identifiable, Equatable, Hashable {
    let id: String
    let family: ModelFamily
    let version: String
    let modelId: String
    let displayName: String
    /// True only for the plain family alias (`opus`, `sonnet`, ...), the row selected when
    /// the user switches family in the picker.
    let isLatest: Bool
    /// Legacy models stay in the catalog so existing configs still resolve to a
    /// readable display name, but they're hidden from the picker.
    var isLegacy: Bool = false
    var kind: ModelKind = .previous
}

// Claude Code 2.1.322: opus/sonnet/haiku/fable resolve to 5.5/5.5/5.5/5.2 and all four are
// natively 1M-context, so the picker no longer offers `[1m]` rows for them. The suffix is
// still accepted, so the old rows are kept hidden (legacy) to render readable names.
let allModelVersions: [ModelVersion] = [
    // Fable
    ModelVersion(id: "claude-fable-5-2", family: .fable, version: "5.2", modelId: "claude-fable-5-2", displayName: "Fable 5.2", isLatest: false, kind: .current),
    ModelVersion(id: "claude-fable-5-1", family: .fable, version: "5.1", modelId: "claude-fable-5-1", displayName: "Fable 5.1", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-fable-5[1m]", family: .fable, version: "5 (1M)", modelId: "claude-fable-5[1m]", displayName: "Fable 5", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-fable-5", family: .fable, version: "5", modelId: "claude-fable-5", displayName: "Fable 5", isLatest: false, isLegacy: true),
    ModelVersion(id: "fable", family: .fable, version: "", modelId: "fable", displayName: "Fable (latest)", isLatest: true, kind: .alias),

    // Opus
    ModelVersion(id: "claude-opus-5-5", family: .opus, version: "5.5", modelId: "claude-opus-5-5", displayName: "Opus 5.5", isLatest: false, kind: .current),
    ModelVersion(id: "claude-opus-5-5[1m]", family: .opus, version: "5.5 (1M)", modelId: "claude-opus-5-5[1m]", displayName: "Opus 5.5", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-5", family: .opus, version: "5", modelId: "claude-opus-5", displayName: "Opus 5 · Previous Opus version", isLatest: false),
    ModelVersion(id: "claude-opus-5[1m]", family: .opus, version: "5 (1M)", modelId: "claude-opus-5[1m]", displayName: "Opus 5", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-8[1m]", family: .opus, version: "4.8 (1M)", modelId: "claude-opus-4-8[1m]", displayName: "Opus 4.8 (1M context)", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-8", family: .opus, version: "4.8", modelId: "claude-opus-4-8", displayName: "Opus 4.8", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-7[1m]", family: .opus, version: "4.7 (1M)", modelId: "claude-opus-4-7[1m]", displayName: "Opus 4.7 (1M context)", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-7", family: .opus, version: "4.7", modelId: "claude-opus-4-7", displayName: "Opus 4.7", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-6[1m]", family: .opus, version: "4.6 (1M)", modelId: "claude-opus-4-6[1m]", displayName: "Opus 4.6 (1M context)", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-6", family: .opus, version: "4.6", modelId: "claude-opus-4-6", displayName: "Opus 4.6", isLatest: false, isLegacy: true),
    ModelVersion(id: "opus", family: .opus, version: "", modelId: "opus", displayName: "Opus (latest)", isLatest: true, kind: .alias),
    // Hidden: accepted by /model but no longer offered (the 1M suffix has no effect on 5.x).
    ModelVersion(id: "opus[1m]", family: .opus, version: "", modelId: "opus[1m]", displayName: "Opus (latest)", isLatest: false, isLegacy: true, kind: .alias),
    ModelVersion(id: "opusplan", family: .opus, version: "", modelId: "opusplan", displayName: "Opus Plan (Opus in plan mode, Sonnet otherwise)", isLatest: false, kind: .alias),

    // Sonnet
    ModelVersion(id: "claude-sonnet-5-5", family: .sonnet, version: "5.5", modelId: "claude-sonnet-5-5", displayName: "Sonnet 5.5", isLatest: false, kind: .current),
    ModelVersion(id: "claude-sonnet-5", family: .sonnet, version: "5", modelId: "claude-sonnet-5", displayName: "Sonnet 5 · Previous Sonnet version", isLatest: false),
    ModelVersion(id: "claude-sonnet-5[1m]", family: .sonnet, version: "5 (1M)", modelId: "claude-sonnet-5[1m]", displayName: "Sonnet 5", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-sonnet-4-6[1m]", family: .sonnet, version: "4.6 (1M)", modelId: "claude-sonnet-4-6[1m]", displayName: "Sonnet 4.6 (1M context)", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-sonnet-4-6", family: .sonnet, version: "4.6", modelId: "claude-sonnet-4-6", displayName: "Sonnet 4.6", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-sonnet-4-5-20250929", family: .sonnet, version: "4.5", modelId: "claude-sonnet-4-5-20250929", displayName: "Sonnet 4.5", isLatest: false, isLegacy: true),
    ModelVersion(id: "sonnet", family: .sonnet, version: "", modelId: "sonnet", displayName: "Sonnet (latest)", isLatest: true, kind: .alias),
    ModelVersion(id: "sonnet[1m]", family: .sonnet, version: "", modelId: "sonnet[1m]", displayName: "Sonnet (latest)", isLatest: false, isLegacy: true, kind: .alias),

    // Haiku
    ModelVersion(id: "claude-haiku-5-5", family: .haiku, version: "5.5", modelId: "claude-haiku-5-5", displayName: "Haiku 5.5", isLatest: false, kind: .current),
    ModelVersion(id: "claude-haiku-4-5-20251001", family: .haiku, version: "4.5", modelId: "claude-haiku-4-5-20251001", displayName: "Haiku 4.5", isLatest: false),
    ModelVersion(id: "claude-3-5-haiku-20241022", family: .haiku, version: "3.5", modelId: "claude-3-5-haiku-20241022", displayName: "Haiku 3.5", isLatest: false, isLegacy: true),
    ModelVersion(id: "haiku", family: .haiku, version: "", modelId: "haiku", displayName: "Haiku (latest)", isLatest: true, kind: .alias),
]

let defaultModelId = "sonnet"

/// Current (non-legacy) versions shown in pickers.
func versions(for family: ModelFamily) -> [ModelVersion] {
    allModelVersions.filter { $0.family == family && !$0.isLegacy }
}

func findModel(byModelId modelId: String) -> ModelVersion? {
    allModelVersions.first { $0.modelId == modelId }
}

func family(for modelId: String) -> ModelFamily? {
    if let version = findModel(byModelId: modelId) {
        return version.family
    }
    let lower = modelId.lowercased()
    if lower.contains("fable") { return .fable }
    if lower.contains("opus") { return .opus }
    if lower.contains("sonnet") { return .sonnet }
    if lower.contains("haiku") { return .haiku }
    return nil
}

func displayName(for modelId: String) -> String {
    if modelId.isEmpty { return "Default (not set)" }
    if let version = findModel(byModelId: modelId) {
        return version.displayName
    }
    return modelId
}

// MARK: - Canonical model ids

/// Alias -> concrete first-party id, as resolved by Claude Code 2.1.322 on first-party auth.
/// `best` resolves to opus; `opusplan` is keyed by its Sonnet model (the model effort is
/// persisted against).
private let aliasTargets: [String: String] = [
    "opus": "claude-opus-5-5",
    "sonnet": "claude-sonnet-5-5",
    "haiku": "claude-haiku-5-5",
    "fable": "claude-fable-5-2",
    "best": "claude-opus-5-5",
    "opusplan": "claude-sonnet-5-5",
]

/// Mirrors the CLI's key normalisation for `modelSettings.<key>`: resolve aliases, drop a
/// trailing `[1m]`, drop Bedrock/Vertex wrapping and date suffixes. Returns "" for "".
func canonicalModelId(_ raw: String) -> String {
    var id = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if id.hasSuffix("[1m]") { id = String(id.dropLast(4)) }
    if let target = aliasTargets[id] { return target }
    // Bedrock: [region.]anthropic.claude-...-v1:0   Vertex: claude-...@20250929
    if let r = id.range(of: "anthropic.") { id = String(id[r.upperBound...]) }
    if let at = id.firstIndex(of: "@") { id = String(id[..<at]) }
    if let r = id.range(of: "-v[0-9]+(:[0-9]+)?$", options: .regularExpression) { id.removeSubrange(r) }
    if let r = id.range(of: "-[0-9]{8}$", options: .regularExpression) { id.removeSubrange(r) }
    return id
}

/// Canonical ids for which the top-level `effortLevel` applies in user scope. This is the
/// CLI's own explicit allowlist, copied from Claude Code 2.1.322. Every other id (the 5.5
/// generation, new models, custom/unknown ids) reads `modelSettings.<id>.effortLevel`.
private let topLevelEffortModelIds: Set<String> = [
    "claude-3-5-haiku", "claude-3-5-sonnet", "claude-3-7-sonnet", "claude-haiku-4-5",
    "claude-sonnet-4-0", "claude-sonnet-4-5", "claude-sonnet-4-6", "claude-sonnet-5",
    "claude-opus-4-0", "claude-opus-4-1", "claude-opus-4-5", "claude-opus-4-6",
    "claude-opus-4-7", "claude-opus-4-8", "claude-opus-5",
    "claude-fable-5", "claude-fable-5-1", "claude-mythos-5", "claude-mythos-5-1",
]

/// True when the top-level `effortLevel` applies to this canonical id (user scope).
func usesLegacyTopLevelEffort(canonicalId id: String) -> Bool {
    topLevelEffortModelIds.contains(id)
}
