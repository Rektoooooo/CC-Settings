import SwiftUI

/// Reference SwiftUI view describing the menu bar dropdown content.
/// The actual menu bar uses NSMenu (see MenuBarController), but this view
/// documents the intended layout and can be used for future SwiftUI-based menus.
struct MenuBarStatusView: View {
    @ObservedObject private var configManager = ConfigurationManager.shared

    let onToggleHUD: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Model status header
            HStack {
                if let modelFamily = family(for: configManager.settings.model) {
                    Image(systemName: modelFamily.icon)
                        .foregroundStyle(.secondary)
                }
                Text(displayName(for: configManager.settings.model))
                    .font(.headline)
                Spacer()
                if configManager.settings.alwaysThinkingEnabled == true {
                    Label("Thinking", systemImage: "brain")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Model families
            ForEach(ModelFamily.allCases) { modelFamily in
                Menu {
                    ForEach(versions(for: modelFamily)) { version in
                        Button {
                            configManager.settings.model = version.modelId
                            configManager.saveSettings()
                        } label: {
                            HStack {
                                Text(version.displayName)
                                if configManager.settings.model == version.modelId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label(modelFamily.rawValue, systemImage: modelFamily.icon)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }

            Divider()

            // Thinking toggle
            Button {
                let current = configManager.settings.alwaysThinkingEnabled == true
                configManager.settings.alwaysThinkingEnabled = current ? nil : true
                if !current && configManager.settings.thinkingBudgetTokens == nil {
                    configManager.settings.thinkingBudgetTokens = 10000
                }
                if current {
                    configManager.settings.thinkingBudgetTokens = nil
                }
                configManager.saveSettings()
            } label: {
                HStack {
                    Label("Extended Thinking", systemImage: "brain")
                    Spacer()
                    if configManager.settings.alwaysThinkingEnabled == true {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // HUD toggle
            Button {
                onToggleHUD()
            } label: {
                Label("Show HUD", systemImage: "rectangle.on.rectangle")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider()

            // Open Settings
            Button {
                onOpenSettings()
            } label: {
                Label("Open Settings...", systemImage: "gear")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit
            Button {
                onQuit()
            } label: {
                Label("Quit CC Settings", systemImage: "xmark.circle")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 240)
        .padding(.vertical, 8)
    }
}
