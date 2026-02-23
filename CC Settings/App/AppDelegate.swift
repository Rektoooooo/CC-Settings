import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        Task { @MainActor in
            FileWatcher.shared.startWatching()
            ConfigurationManager.shared.loadAll()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            FileWatcher.shared.stopWatching()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
