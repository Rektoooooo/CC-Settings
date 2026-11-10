import Foundation

// MARK: - Built-in themes

/// A theme that ships inside Claude Code. Read-only here: you can activate it (writes its id
/// to `settings.json:theme`) or duplicate it as the `base` of an editable custom theme.
///
/// The "auto" id is a sentinel for "no theme set" -- selecting it clears `settings.json:theme`.
struct BuiltInTheme: Identifiable, Hashable {
    let id: String          // value written to `settings.json:theme` ("auto" clears it)
    let displayName: String
    let icon: String
    let description: String
    /// Palette this theme uses (nil for Auto, which follows the terminal).
    let base: String?

    static let autoID = "auto"
    var isAuto: Bool { id == BuiltInTheme.autoID }

    static func == (lhs: BuiltInTheme, rhs: BuiltInTheme) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum ThemePresets {
    /// The themes Claude Code's `/theme` picker offers. Their palettes are the exact ones
    /// shipped in the CLI (`ClaudeThemePalette`), so previews are not approximations.
    static let builtIns: [BuiltInTheme] = [
        BuiltInTheme(
            id: BuiltInTheme.autoID,
            displayName: "Auto (match terminal)",
            icon: "circle.lefthalf.filled",
            description: "Follows your terminal's light or dark appearance. No theme setting is written.",
            base: nil
        ),
        BuiltInTheme(id: "dark", displayName: "Dark mode", icon: "moon.fill",
                     description: "Claude Code's default dark theme.", base: "dark"),
        BuiltInTheme(id: "light", displayName: "Light mode", icon: "sun.max.fill",
                     description: "Claude Code's default light theme.", base: "light"),
        BuiltInTheme(id: "dark-daltonized", displayName: "Dark mode (colorblind-friendly)", icon: "moon.circle.fill",
                     description: "Dark theme with colours adjusted for colour-vision deficiency.", base: "dark-daltonized"),
        BuiltInTheme(id: "light-daltonized", displayName: "Light mode (colorblind-friendly)", icon: "sun.max.circle.fill",
                     description: "Light theme with colours adjusted for colour-vision deficiency.", base: "light-daltonized"),
        BuiltInTheme(id: "dark-ansi", displayName: "Dark mode (ANSI colors only)", icon: "terminal.fill",
                     description: "Uses only your terminal's 16 ANSI colours, on a dark background.", base: "dark-ansi"),
        BuiltInTheme(id: "light-ansi", displayName: "Light mode (ANSI colors only)", icon: "terminal",
                     description: "Uses only your terminal's 16 ANSI colours, on a light background.", base: "light-ansi"),
    ]

    /// Starter templates for the New menu. Each is a `base` plus a handful of overrides
    /// using real palette keys.
    struct Preset: Identifiable {
        let id: String
        let displayName: String
        let suggestedFilename: String
        let base: String
        let overrides: [String: String]
    }

    static let starters: [Preset] = [
        Preset(
            id: "midnight", displayName: "Midnight", suggestedFilename: "midnight", base: "dark",
            overrides: [
                "claude": "#bd93f9", "claudeShimmer": "#d6b8ff", "permission": "#8be9fd",
                "success": "#50fa7b", "error": "#ff5555", "warning": "#ffb86c",
                "promptBorder": "#6272a4", "bashBorder": "#ff79c6", "planMode": "#8be9fd",
                "diffAdded": "#1f4d2e", "diffRemoved": "#5a2430",
            ]
        ),
        Preset(
            id: "solarized-dark", displayName: "Solarized Dark", suggestedFilename: "solarized-dark", base: "dark",
            overrides: [
                "claude": "#cb4b16", "permission": "#268bd2", "success": "#859900",
                "error": "#dc322f", "warning": "#b58900", "promptBorder": "#586e75",
                "bashBorder": "#d33682", "planMode": "#2aa198", "subtle": "#586e75",
            ]
        ),
        Preset(
            id: "nord", displayName: "Nord", suggestedFilename: "nord", base: "dark",
            overrides: [
                "claude": "#88c0d0", "permission": "#81a1c1", "success": "#a3be8c",
                "error": "#bf616a", "warning": "#ebcb8b", "promptBorder": "#4c566a",
                "bashBorder": "#b48ead", "planMode": "#8fbcbb", "subtle": "#616e88",
            ]
        ),
    ]
}
