import SwiftUI

struct ContentView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var selection: NavigationItem = .general

    @State private var sidebarVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(selection: $selection)
                .environmentObject(configManager)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 350)
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
        case .projectSettings(let projectId):
            ProjectSettingsView(projectId: projectId)
        case .projectClaudeMD(let projectId):
            ClaudeMDEditorView(projectId: projectId)
        case .projectSessions(let projectId):
            SessionBrowserView(projectId: projectId)
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
        case .agents:
            AgentsView()
        case .rules:
            RulesView()
        case .stats:
            StatsView()
        case .cleanup:
            CleanupView()
        case .sync:
            VersionControlView()
        case .folder(let name):
            if name == "file-history" {
                FileHistoryView()
            } else if name == "tasks" {
                TasksView()
            } else {
                FilesEditorView(contentItem: .folder(name))
            }
        case .none:
            Text("Select an item from the sidebar")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }
}
