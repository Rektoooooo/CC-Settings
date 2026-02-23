import AppKit

@MainActor
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var hudPanel: HUDPanel?

    private static let hudVisibleKey = "HUDPanel.isVisible"

    override init() {
        super.init()
        setupStatusItem()
        if UserDefaults.standard.bool(forKey: Self.hudVisibleKey) {
            hudPanel = HUDPanel()
            hudPanel?.orderFront(nil)
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "gear.circle", accessibilityDescription: "CC Settings")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            showMenu()
        } else {
            activateApp()
        }
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - HUD

    func toggleHUD() {
        if let panel = hudPanel, panel.isVisible {
            panel.orderOut(nil)
            UserDefaults.standard.set(false, forKey: Self.hudVisibleKey)
        } else {
            if hudPanel == nil {
                hudPanel = HUDPanel()
            }
            hudPanel?.orderFront(nil)
            UserDefaults.standard.set(true, forKey: Self.hudVisibleKey)
        }
    }

    private var isHUDVisible: Bool {
        hudPanel?.isVisible ?? false
    }

    // MARK: - Thinking

    func toggleThinking() {
        let config = ConfigurationManager.shared
        let isCurrentlyEnabled = config.settings.alwaysThinkingEnabled == true
        config.settings.alwaysThinkingEnabled = isCurrentlyEnabled ? nil : true
        if !isCurrentlyEnabled && config.settings.thinkingBudgetTokens == nil {
            config.settings.thinkingBudgetTokens = 10000
        }
        if isCurrentlyEnabled {
            config.settings.thinkingBudgetTokens = nil
        }
        config.saveSettings()
    }

    // MARK: - Menu

    private func showMenu() {
        let menu = NSMenu()

        // Current model header
        let currentModel = ConfigurationManager.shared.settings.model
        let currentName = displayName(for: currentModel)
        let headerItem = NSMenuItem(title: currentName, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(NSMenuItem.separator())

        // Model family submenus
        for modelFamily in ModelFamily.allCases {
            let familyItem = NSMenuItem(title: modelFamily.rawValue, action: nil, keyEquivalent: "")
            familyItem.image = NSImage(systemSymbolName: modelFamily.icon, accessibilityDescription: modelFamily.rawValue)

            let submenu = NSMenu()
            for version in versions(for: modelFamily) {
                let versionItem = NSMenuItem(
                    title: version.displayName,
                    action: #selector(selectModel(_:)),
                    keyEquivalent: ""
                )
                versionItem.target = self
                versionItem.representedObject = version.modelId
                if currentModel == version.modelId {
                    versionItem.state = .on
                }
                submenu.addItem(versionItem)
            }
            familyItem.submenu = submenu
            menu.addItem(familyItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Thinking toggle
        let thinkingItem = NSMenuItem(
            title: "Extended Thinking",
            action: #selector(thinkingMenuItemClicked),
            keyEquivalent: ""
        )
        thinkingItem.target = self
        thinkingItem.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "Thinking")
        if ConfigurationManager.shared.settings.alwaysThinkingEnabled == true {
            thinkingItem.state = .on
        }
        menu.addItem(thinkingItem)

        // HUD toggle
        let hudTitle = isHUDVisible ? "Hide HUD" : "Show HUD"
        let hudItem = NSMenuItem(
            title: hudTitle,
            action: #selector(hudMenuItemClicked),
            keyEquivalent: ""
        )
        hudItem.target = self
        hudItem.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "HUD")
        menu.addItem(hudItem)

        menu.addItem(NSMenuItem.separator())

        // Open Settings
        let openItem = NSMenuItem(title: "Open Settings...", action: #selector(openSettings), keyEquivalent: ",")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit CC Settings", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    // MARK: - Actions

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let modelId = sender.representedObject as? String else { return }
        ConfigurationManager.shared.settings.model = modelId
        ConfigurationManager.shared.saveSettings()
    }

    @objc private func thinkingMenuItemClicked() {
        toggleThinking()
    }

    @objc private func hudMenuItemClicked() {
        toggleHUD()
    }

    @objc private func openSettings() {
        activateApp()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
