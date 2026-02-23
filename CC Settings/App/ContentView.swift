import SwiftUI

struct ContentView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var selection: NavigationItem = .general

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .environmentObject(configManager)
        } detail: {
            
            detailView
                .id(selection)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .general:
            GeneralSettingsView()
        case .permissions:
            PermissionsView()
        case .environment:
            EnvironmentView()
        case .experimentalFeatures:
            ExperimentalFeaturesView()
        case .hooks:
            HooksView()
        case .hud:
            HUDView()
        case .globalFiles:
            FilesEditorView(contentItem: .general)
        case .projectFiles(let projectId):
            FilesEditorView(contentItem: .project(projectId))
        case .claudeMDEditor:
            ClaudeMDEditorView()
        case .sessionHistory:
            SessionBrowserView()
        case .commands:
            CommandsView()
        case .skills:
            SkillsView()
        case .plugins:
            PluginsView()
        case .mcpServers:
            MCPServersView()
        case .cleanup:
            CleanupView()
        case .sync:
            VersionControlView()
        case .folder(let name):
            FilesEditorView(contentItem: .folder(name))
        case .none:
            Text("Select an item from the sidebar")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}
