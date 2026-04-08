import Foundation

struct SettingsProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var createdAt: Date
    var updatedAt: Date
    var settings: ClaudeSettings
    var rawSettingsJSON: Data

    static func == (lhs: SettingsProfile, rhs: SettingsProfile) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.description == rhs.description
            && lhs.createdAt == rhs.createdAt
            && lhs.updatedAt == rhs.updatedAt
            && lhs.rawSettingsJSON == rhs.rawSettingsJSON
    }

    /// Human-readable summary of key settings for display in profile rows.
    var settingsSummary: String {
        var parts: [String] = []
        parts.append("Model: \(settings.model)")
        if let theme = settings.theme, !theme.isEmpty {
            parts.append("Theme: \(theme)")
        }
        if let effort = settings.effortLevel, !effort.isEmpty {
            parts.append("Effort: \(effort)")
        }
        return parts.joined(separator: " · ")
    }
}
