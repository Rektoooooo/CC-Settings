import Foundation

/// Git preferences that only CC Settings uses (main branch label, external git app).
/// Claude Code does not read `mainBranch`, `preferredGitApp` or `customGitAppPath`, so they
/// live in the app's UserDefaults instead of `~/.claude/settings.json`.
enum AppGitPreferences {
    static let mainBranchKey = "appGit.mainBranch"
    static let appKey = "appGit.preferredApp"
    static let customPathKey = "appGit.customAppPath"
    private static let migratedKey = "appGit.migratedFromSettings"

    /// Copies values an older build wrote into settings.json, once. The keys are left in the
    /// user's file untouched; the app just stops writing them.
    static func migrateIfNeeded(from settings: ClaudeSettings, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: migratedKey) else { return }
        if defaults.object(forKey: mainBranchKey) == nil, let branch = settings.mainBranch, !branch.isEmpty {
            defaults.set(branch, forKey: mainBranchKey)
        }
        if defaults.object(forKey: appKey) == nil, let app = settings.preferredGitApp {
            defaults.set(app.rawValue, forKey: appKey)
        }
        if defaults.object(forKey: customPathKey) == nil, let path = settings.customGitAppPath, !path.isEmpty {
            defaults.set(path, forKey: customPathKey)
        }
        defaults.set(true, forKey: migratedKey)
    }
}
