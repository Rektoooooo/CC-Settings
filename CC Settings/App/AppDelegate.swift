import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        FileWatcher.shared.startWatching()
        ConfigurationManager.shared.loadAll()
    }

    func applicationWillTerminate(_ notification: Notification) {
        FileWatcher.shared.stopWatching()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
