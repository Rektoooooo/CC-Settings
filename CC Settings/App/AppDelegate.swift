import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        let manager = ConfigurationManager.shared
        manager.loadAll()

        // Seed project paths before starting the watcher so it monitors
        // both ~/.claude/ and each project's .claude/ directory.
        let projects = manager.loadProjects()
        FileWatcher.shared.updateProjectPaths(projects)
        FileWatcher.shared.startWatching()
    }

    func applicationWillTerminate(_ notification: Notification) {
        FileWatcher.shared.stopWatching()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
