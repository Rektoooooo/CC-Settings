import Foundation

enum ModelFamily: String, CaseIterable, Identifiable {
    case opus = "Opus"
    case sonnet = "Sonnet"
    case haiku = "Haiku"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .opus: return "brain.head.profile"
        case .sonnet: return "sparkles"
        case .haiku: return "hare"
        }
    }

    var description: String {
        switch self {
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
}

let allModelVersions: [ModelVersion] = [
    ModelVersion(id: "claude-opus-4-6", family: .opus, version: "4.6", modelId: "claude-opus-4-6", displayName: "Opus 4.6", isLatest: false),
    ModelVersion(id: "claude-opus-4-20250514", family: .opus, version: "4.0", modelId: "claude-opus-4-20250514", displayName: "Opus 4.0", isLatest: false),
    ModelVersion(id: "opus", family: .opus, version: "", modelId: "opus", displayName: "Opus (latest)", isLatest: true),
    ModelVersion(id: "claude-sonnet-4-5-20250514", family: .sonnet, version: "4.5", modelId: "claude-sonnet-4-5-20250514", displayName: "Sonnet 4.5", isLatest: false),
    ModelVersion(id: "claude-sonnet-4-20250514", family: .sonnet, version: "4.0", modelId: "claude-sonnet-4-20250514", displayName: "Sonnet 4.0", isLatest: false),
    ModelVersion(id: "sonnet", family: .sonnet, version: "", modelId: "sonnet", displayName: "Sonnet (latest)", isLatest: true),
    ModelVersion(id: "claude-3-5-haiku-20241022", family: .haiku, version: "3.5", modelId: "claude-3-5-haiku-20241022", displayName: "Haiku 3.5", isLatest: false),
    ModelVersion(id: "haiku", family: .haiku, version: "", modelId: "haiku", displayName: "Haiku (latest)", isLatest: true),
]

let defaultModelId = "sonnet"

func versions(for family: ModelFamily) -> [ModelVersion] {
    allModelVersions.filter { $0.family == family }
}

func findModel(byModelId modelId: String) -> ModelVersion? {
    allModelVersions.first { $0.modelId == modelId }
}

func family(for modelId: String) -> ModelFamily? {
    if let version = findModel(byModelId: modelId) {
        return version.family
    }
    let lower = modelId.lowercased()
    if lower.contains("opus") { return .opus }
    if lower.contains("sonnet") { return .sonnet }
    if lower.contains("haiku") { return .haiku }
    return nil
}

func displayName(for modelId: String) -> String {
    if let version = findModel(byModelId: modelId) {
        return version.displayName
    }
    return modelId
}
