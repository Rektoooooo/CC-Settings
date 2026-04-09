import SwiftUI
import Sparkle

@main
struct CCSettingsApp: App {
    @StateObject private var configManager = ConfigurationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var profileManager = ProfileManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(configManager)
                .environmentObject(themeManager)
                .environmentObject(profileManager)
                .environment(\.sparkleUpdater, updaterController.updater)
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
            CommandGroup(after: .appInfo) {
                Button("Check for App Updates...") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }

        Settings {
            EmptyView()
        }
    }
}
