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

struct ModelVersion: Identifiable, Equatable, Hashable {
    let id: String
    let family: ModelFamily
    let version: String
    let modelId: String
    let displayName: String
    let isLatest: Bool
    /// Legacy models stay in the catalog so existing configs still resolve to a
    /// readable display name, but they're hidden from the picker.
    var isLegacy: Bool = false
}

let allModelVersions: [ModelVersion] = [
    // Fable
    // NOTE: neither Fable 5 nor Fable 5.1 has a `[1m]` variant — both are natively
    // 1M-context, and Claude Code's picker offers no "(1M context)" row for either.
    // v1.5.0 offered `claude-fable-5[1m]` by mistake; kept here (hidden) only so
    // configs written by that build still resolve to a readable name.
    ModelVersion(id: "claude-fable-5[1m]", family: .fable, version: "5 (1M)", modelId: "claude-fable-5[1m]", displayName: "Fable 5", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-fable-5-1", family: .fable, version: "5.1", modelId: "claude-fable-5-1", displayName: "Fable 5.1", isLatest: false),
    ModelVersion(id: "claude-fable-5", family: .fable, version: "5", modelId: "claude-fable-5", displayName: "Fable 5", isLatest: false, isLegacy: true),
    ModelVersion(id: "fable", family: .fable, version: "", modelId: "fable", displayName: "Fable (latest)", isLatest: true),

    // Opus
    ModelVersion(id: "claude-opus-5[1m]", family: .opus, version: "5 (1M)", modelId: "claude-opus-5[1m]", displayName: "Opus 5 (1M context)", isLatest: false),
    ModelVersion(id: "claude-opus-5", family: .opus, version: "5", modelId: "claude-opus-5", displayName: "Opus 5", isLatest: false),
    ModelVersion(id: "claude-opus-4-8[1m]", family: .opus, version: "4.8 (1M)", modelId: "claude-opus-4-8[1m]", displayName: "Opus 4.8 (1M context)", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-8", family: .opus, version: "4.8", modelId: "claude-opus-4-8", displayName: "Opus 4.8", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-7[1m]", family: .opus, version: "4.7 (1M)", modelId: "claude-opus-4-7[1m]", displayName: "Opus 4.7 (1M context)", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-7", family: .opus, version: "4.7", modelId: "claude-opus-4-7", displayName: "Opus 4.7", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-6[1m]", family: .opus, version: "4.6 (1M)", modelId: "claude-opus-4-6[1m]", displayName: "Opus 4.6 (1M context)", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-opus-4-6", family: .opus, version: "4.6", modelId: "claude-opus-4-6", displayName: "Opus 4.6", isLatest: false, isLegacy: true),
    ModelVersion(id: "opus", family: .opus, version: "", modelId: "opus", displayName: "Opus (latest)", isLatest: true),

    // Sonnet
    // Unlike Fable, Sonnet 5 DOES expose a `[1m]` row ("Sonnet 5 (1M context)") in
    // Claude Code's picker. v1.5.1 assumed it didn't and omitted it.
    ModelVersion(id: "claude-sonnet-5[1m]", family: .sonnet, version: "5 (1M)", modelId: "claude-sonnet-5[1m]", displayName: "Sonnet 5 (1M context)", isLatest: false),
    ModelVersion(id: "claude-sonnet-5", family: .sonnet, version: "5", modelId: "claude-sonnet-5", displayName: "Sonnet 5", isLatest: false),
    ModelVersion(id: "claude-sonnet-4-6[1m]", family: .sonnet, version: "4.6 (1M)", modelId: "claude-sonnet-4-6[1m]", displayName: "Sonnet 4.6 (1M context)", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-sonnet-4-6", family: .sonnet, version: "4.6", modelId: "claude-sonnet-4-6", displayName: "Sonnet 4.6", isLatest: false, isLegacy: true),
    ModelVersion(id: "claude-sonnet-4-5-20250929", family: .sonnet, version: "4.5", modelId: "claude-sonnet-4-5-20250929", displayName: "Sonnet 4.5", isLatest: false, isLegacy: true),
    ModelVersion(id: "sonnet", family: .sonnet, version: "", modelId: "sonnet", displayName: "Sonnet (latest)", isLatest: true),

    // Haiku
    ModelVersion(id: "claude-haiku-4-5-20251001", family: .haiku, version: "4.5", modelId: "claude-haiku-4-5-20251001", displayName: "Haiku 4.5", isLatest: false),
    ModelVersion(id: "claude-3-5-haiku-20241022", family: .haiku, version: "3.5", modelId: "claude-3-5-haiku-20241022", displayName: "Haiku 3.5", isLatest: false, isLegacy: true),
    ModelVersion(id: "haiku", family: .haiku, version: "", modelId: "haiku", displayName: "Haiku (latest)", isLatest: true),
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
