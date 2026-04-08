import Foundation
import SwiftUI

@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var profiles: [SettingsProfile] = []

    private let profilesDir: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        profilesDir = home.appendingPathComponent(".claude").appendingPathComponent("profiles")
        loadProfiles()
    }

    // MARK: - Load

    func loadProfiles() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: profilesDir.path) else {
            profiles = []
            return
        }

        do {
            let files = try fm.contentsOfDirectory(at: profilesDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }

            var loaded: [SettingsProfile] = []
            for file in files {
                do {
                    let data = try Data(contentsOf: file)
                    let profile = try decoder.decode(SettingsProfile.self, from: data)
                    loaded.append(profile)
                } catch {
                    // Skip corrupt files
                }
            }
            profiles = loaded.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            profiles = []
        }
    }

    // MARK: - Save Current Settings as Profile

    func saveCurrentAsProfile(name: String, description: String) throws {
        let configManager = ConfigurationManager.shared

        // Read raw JSON bytes directly from disk (preserves unknown CLI keys)
        let rawJSON = try Data(contentsOf: configManager.settingsURL)

        // Decode settings for display metadata
        let settingsDecoder = JSONDecoder()
        let fixed = configManager.validateAndFix(jsonData: rawJSON)
        let settings = try settingsDecoder.decode(ClaudeSettings.self, from: fixed)

        let now = Date()
        let profile = SettingsProfile(
            id: UUID(),
            name: name,
            description: description,
            createdAt: now,
            updatedAt: now,
            settings: settings,
            rawSettingsJSON: rawJSON
        )

        try saveProfileToDisk(profile)
        profiles.insert(profile, at: 0)
    }

    // MARK: - Update Metadata

    func updateProfile(_ profile: SettingsProfile) throws {
        var updated = profile
        updated.updatedAt = Date()
        try saveProfileToDisk(updated)

        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = updated
        }
        profiles.sort { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Overwrite with Current Settings

    func overwriteProfile(_ profile: SettingsProfile) throws {
        let configManager = ConfigurationManager.shared

        let rawJSON = try Data(contentsOf: configManager.settingsURL)
        let settingsDecoder = JSONDecoder()
        let fixed = configManager.validateAndFix(jsonData: rawJSON)
        let settings = try settingsDecoder.decode(ClaudeSettings.self, from: fixed)

        var updated = profile
        updated.updatedAt = Date()
        updated.settings = settings
        updated.rawSettingsJSON = rawJSON

        try saveProfileToDisk(updated)

        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = updated
        }
        profiles.sort { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Delete

    func deleteProfile(_ profile: SettingsProfile) throws {
        let fileURL = profilesDir.appendingPathComponent("\(profile.id.uuidString).json")
        try FileManager.default.removeItem(at: fileURL)
        profiles.removeAll { $0.id == profile.id }
    }

    // MARK: - Load Profile into Settings

    func loadProfile(_ profile: SettingsProfile, into configManager: ConfigurationManager) {
        configManager.writeRawSettingsAndReload(profile.rawSettingsJSON)
    }

    // MARK: - Duplicate

    func duplicateProfile(_ profile: SettingsProfile, newName: String) throws {
        let now = Date()
        let duplicate = SettingsProfile(
            id: UUID(),
            name: newName,
            description: profile.description,
            createdAt: now,
            updatedAt: now,
            settings: profile.settings,
            rawSettingsJSON: profile.rawSettingsJSON
        )

        try saveProfileToDisk(duplicate)
        profiles.insert(duplicate, at: 0)
    }

    // MARK: - Helpers

    private func saveProfileToDisk(_ profile: SettingsProfile) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: profilesDir.path) {
            try fm.createDirectory(at: profilesDir, withIntermediateDirectories: true)
        }

        let data = try encoder.encode(profile)
        let fileURL = profilesDir.appendingPathComponent("\(profile.id.uuidString).json")
        try data.write(to: fileURL, options: .atomic)
    }
}
