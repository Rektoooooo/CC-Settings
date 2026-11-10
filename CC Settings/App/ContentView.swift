import SwiftUI

struct ContentView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var selection: NavigationItem = .general
    @State private var scrollToSection: String?

    @State private var sidebarVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(selection: $selection, scrollToSection: $scrollToSection)
                .environmentObject(configManager)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 350)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let error = configManager.lastError {
                errorBanner(error)
            }
        }
    }

    /// Surfaces `configManager.lastError` (failed or refused writes, undecodable files).
    private func errorBanner(_ error: Error) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(error.localizedDescription)
                .font(.subheadline)
                .lineLimit(3)
                .textSelection(.enabled)
            Spacer(minLength: 8)
            Button {
                configManager.lastError = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(10)
        .glassBanner(tint: .orange)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .general:
            GeneralSettingsView(scrollToSection: $scrollToSection)
        case .permissions:
            PermissionsView(scrollToSection: $scrollToSection)
        case .environment:
            EnvironmentView(scrollToSection: $scrollToSection)
        case .experimentalFeatures:
            ExperimentalFeaturesView(scrollToSection: $scrollToSection)
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
        case .themes:
            ThemesView()
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
