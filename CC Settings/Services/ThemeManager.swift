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
            Color(red: 224/255, green: 122/255, blue: 95/255) // #E07A5F
        case .ocean, .darkDaltonized, .lightDaltonized:
            Color(red: 74/255, green: 144/255, blue: 217/255) // #4A90D9
        case .forest:
            Color(red: 91/255, green: 165/255, blue: 91/255) // #5BA55B
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
    }
}
