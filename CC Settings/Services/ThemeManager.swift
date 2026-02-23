import SwiftUI
import AppKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case claude
    case claudeLight
    case ocean
    case forest
    case darkDaltonized
    case lightDaltonized

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .claude: "Claude"
        case .claudeLight: "Claude Light"
        case .ocean: "Ocean"
        case .forest: "Forest"
        case .darkDaltonized: "Dark (Daltonized)"
        case .lightDaltonized: "Light (Daltonized)"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light, .claudeLight, .lightDaltonized: NSAppearance(named: .aqua)
        case .dark, .claude, .ocean, .forest, .darkDaltonized: NSAppearance(named: .darkAqua)
        }
    }

    var accentColor: Color? {
        switch self {
        case .system, .light, .dark:
            nil
        case .claude, .claudeLight:
            Color(red: 218/255, green: 119/255, blue: 86/255) // #DA7756 Claude brand orange
        case .ocean:
            Color(red: 8/255, green: 145/255, blue: 178/255) // #0891B2 teal/cyan
        case .forest:
            Color(red: 91/255, green: 165/255, blue: 91/255) // #5BA55B green
        case .darkDaltonized, .lightDaltonized:
            Color(red: 100/255, green: 143/255, blue: 255/255) // #648FFF colorblind-safe blue
        }
    }

    /// Maps to the CLI-compatible theme string written to settings.json.
    var cliTheme: String? {
        switch self {
        case .system, .dark: nil // CLI default is dark
        case .light: "light"
        case .claude: "dark"
        case .claudeLight: "light"
        case .ocean: "dark"
        case .forest: "dark"
        case .darkDaltonized: "dark-daltonized"
        case .lightDaltonized: "light-daltonized"
        }
    }
}

// MARK: - ThemeManager

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let themeKey = "appTheme"
    @Published var selectedThemeName: String {
        didSet {
            UserDefaults.standard.set(selectedThemeName, forKey: Self.themeKey)
            applyTheme()
        }
    }

    var currentTheme: AppTheme {
        AppTheme(rawValue: selectedThemeName) ?? .system
    }

    var resolvedAccentColor: Color {
        currentTheme.accentColor ?? .accentColor
    }

    private init() {
        self.selectedThemeName = UserDefaults.standard.string(forKey: Self.themeKey) ?? "system"
        applyTheme()
    }

    func applyTheme() {
        NSApp?.appearance = currentTheme.appearance

        // Clean up any previously-set AppleAccentColor so it doesn't
        // override SwiftUI's .tint() for sidebar selection highlights.
        UserDefaults.standard.removeObject(forKey: "AppleAccentColor")
    }
}

// MARK: - Color Extension

extension Color {
    /// The current theme's accent color. Use this instead of `.blue` or `Color.accentColor`
    /// for any UI element that should follow the selected theme.
    ///
    /// Safe to use from SwiftUI views and other @MainActor contexts.
    /// Uses `assumeIsolated` because all call sites are SwiftUI view bodies
    /// which always run on the main actor.
    static var themeAccent: Color {
        MainActor.assumeIsolated {
            ThemeManager.shared.resolvedAccentColor
        }
    }
}
