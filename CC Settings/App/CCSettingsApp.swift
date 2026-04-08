import SwiftUI

@main
struct CCSettingsApp: App {
    @StateObject private var configManager = ConfigurationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var profileManager = ProfileManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(configManager)
                .environmentObject(themeManager)
                .environmentObject(profileManager)
                .tint(themeManager.resolvedAccentColor)
                .accentColor(themeManager.resolvedAccentColor)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear { themeManager.applyTheme() }
                .onChange(of: themeManager.selectedThemeName) { themeManager.applyTheme() }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            EmptyView()
        }
    }
}
