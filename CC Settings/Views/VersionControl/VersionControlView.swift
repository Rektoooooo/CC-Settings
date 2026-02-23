import SwiftUI

struct VersionControlView: View {
    @StateObject private var gitService = GitService.shared
    @EnvironmentObject var configManager: ConfigurationManager

    // Persistence keys
    private static let selectedRepoKey = "VersionControl.selectedRepoPath"
    private static let customReposKey = "VersionControl.customRepoPaths"

    // Repo management
    @State private var repositories: [GitRepository] = []
    @State private var selectedRepo: GitRepository?

    // File & commit selection
    @State private var selectedFile: GitFileChange?
    @State private var selectedCommit: GitCommit?

    // Staging
    @State private var filesToStage: Set<String> = []
    @State private var commitMessage = ""

    // View state
    @State private var viewMode: ViewMode = .changes
    @State private var diffText = ""
    @State private var diffTitle = ""
    @State private var fileSearchText = ""

    // Sheets & alerts
    @State private var showInitSheet = false
    @State private var showRemoteSheet = false
    @State private var showOutputAlert = false
    @State private var outputAlertTitle = ""
    @State private var pushPullOutput: String?

    private enum ViewMode: String, CaseIterable {
        case changes = "Changes"
        case history = "History"
    }

    var body: some View {
        HSplitView {
            leftPane
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            rightPane
                .frame(minWidth: 400)
        }
        .onAppear {
            loadRepositories()
        }
        .onChange(of: selectedRepo) { _, newRepo in
            guard let repo = newRepo else { return }
            selectedFile = nil
            selectedCommit = nil
            diffText = ""
            diffTitle = ""
            filesToStage = []
            commitMessage = ""
            // Persist selection
            UserDefaults.standard.set(repo.path.path, forKey: Self.selectedRepoKey)
            // Set repoPath (didSet handles refresh if changed).
            // If same as current, force a refresh explicitly.
            if gitService.repoPath == repo.path {
                gitService.resetState()
                gitService.refreshStatus()
            } else {
                gitService.repoPath = repo.path
            }
        }
        .onChange(of: selectedFile) { _, newFile in
            selectedCommit = nil
            guard let file = newFile else {
                diffText = ""
                diffTitle = ""
                return
            }
            diffTitle = file.path
            Task {
                diffText = await gitService.getDiffAsync(for: file.path)
            }
        }
        .onChange(of: selectedCommit) { _, newCommit in
            selectedFile = nil
            guard let commit = newCommit else {
                diffText = ""
                diffTitle = ""
                return
            }
            diffTitle = "\(commit.shortHash) — \(commit.message)"
            Task {
                diffText = await gitService.getCommitDiffAsync(hash: commit.id)
            }
        }
        .sheet(isPresented: $showInitSheet) {
            GitInitSheet(gitService: gitService)
        }
        .sheet(isPresented: $showRemoteSheet) {
            RemoteConfigSheet(gitService: gitService)
        }
        .alert(outputAlertTitle, isPresented: $showOutputAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(pushPullOutput ?? "")
        }
    }

    // MARK: - Left Pane

    private var leftPane: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()

            if !gitService.isGitInstalled {
                gitNotInstalledView
            } else if selectedRepo == nil {
                noRepoSelectedView
            } else if gitService.isLoading && !gitService.isGitRepo {
                // Still loading — don't flash "Not a Git Repo" while refresh runs
                Spacer()
                ProgressView("Loading...")
                    .font(.caption)
                Spacer()
            } else if selectedRepo != nil && !gitService.isGitRepo {
                notInitializedView
            } else if gitService.isLoading && gitService.commitLog.isEmpty && gitService.changedFiles.isEmpty {
                Spacer()
                ProgressView("Loading...")
                    .font(.caption)
                Spacer()
            } else {
                repoStatusSection
                Divider()
                viewModePicker
                Divider()

                switch viewMode {
                case .changes:
                    changesTab
                case .history:
                    historyTab
                }

                Divider()
                commitBar
                Divider()
                footerBar
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    Text("Version Control")
                        .font(.headline)
                }
                Spacer()
                if gitService.isLoading || isLoadingRepos {
                    ProgressView()
                        .controlSize(.small)
                }
                Button {
                    gitService.refreshStatus()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }

            HStack(spacing: 8) {
                Picker("Repository", selection: $selectedRepo) {
                    Text("Select a repository...").tag(nil as GitRepository?)
                    ForEach(repositories) { repo in
                        HStack {
                            Image(systemName: repo.isClaudeProject ? "sparkle" : "folder")
                            Text(repo.displayName)
                        }
                        .tag(repo as GitRepository?)
                    }
                }
                .labelsHidden()

                Button {
                    openFolderPanel()
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .help("Open Folder...")
            }

            if let repo = selectedRepo {
                Text(repo.path.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
    }

    // MARK: - Placeholder States

    private var gitNotInstalledView: some View {
        EmptyContentPlaceholder(
            icon: "exclamationmark.triangle",
            title: "Git Not Found",
            subtitle: "Install Xcode Command Line Tools to enable version control."
        )
    }

    private var notInitializedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Not a Git Repository")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Initialize a git repository to start\ntracking changes in this folder.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showInitSheet = true
            } label: {
                Label("Initialize Repository", systemImage: "plus.circle.fill")
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noRepoSelectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Select a Repository")
                .font(.title3)
                .fontWeight(.medium)
            Text("Choose a repository from the picker above\nor open a folder to get started.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Repo Status

    private var repoStatusSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(gitService.isDirty ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(gitService.currentBranch)
                    .font(.caption.monospaced())
                    .fontWeight(.medium)
                Spacer()
                Text(gitService.isDirty ? "Uncommitted changes" : "Clean")
                    .font(.caption)
                    .foregroundColor(gitService.isDirty ? .orange : .green)
            }

            if let remote = gitService.remoteURL {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(remote)
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        Picker("View", selection: $viewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Changes Tab

    private var changesTab: some View {
        VStack(spacing: 0) {
            if !gitService.changedFiles.isEmpty {
                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                    TextField("Filter files...", text: $fileSearchText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredChangedFiles) { file in
                        fileRow(file)
                        if file.id != filteredChangedFiles.last?.id {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
            }

            if !gitService.changedFiles.isEmpty {
                Divider()
                stagingControls
            }
        }
    }

    private var filteredChangedFiles: [GitFileChange] {
        let query = fileSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return gitService.changedFiles }
        return gitService.changedFiles.filter { $0.path.lowercased().contains(query) }
    }

    private func fileRow(_ file: GitFileChange) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { filesToStage.contains(file.path) },
                set: { isOn in
                    if isOn {
                        filesToStage.insert(file.path)
                    } else {
                        filesToStage.remove(file.path)
                    }
                }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)

            Image(systemName: file.status.icon)
                .foregroundColor(file.status.color)
                .font(.caption)

            Text(file.path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(file.status.displayName)
                .font(.caption2)
                .foregroundColor(file.status.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(selectedFile?.path == file.path ? Color.accentColor.opacity(0.15) : Color.clear)
        .onTapGesture {
            selectedFile = file
        }
    }

    private var stagingControls: some View {
        HStack(spacing: 8) {
            Button("Stage All") {
                filesToStage = Set(gitService.changedFiles.map(\.path))
            }
            .font(.caption)
            .buttonStyle(.plain)

            Button("None") {
                filesToStage.removeAll()
            }
            .font(.caption)
            .buttonStyle(.plain)

            Spacer()

            Text("\(filesToStage.count) staged")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Commit Bar

    private var commitBar: some View {
        HStack(spacing: 8) {
            TextField("Commit message...", text: $commitMessage)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit {
                    if canCommit {
                        performCommit()
                    }
                }

            Button {
                performCommit()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!canCommit)
            .help("Commit staged files")
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var canCommit: Bool {
        !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !filesToStage.isEmpty
    }

    private func performCommit() {
        let msg = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let files = Array(filesToStage)
        gitService.commit(message: msg, files: files)
        commitMessage = ""
        filesToStage.removeAll()
        selectedFile = nil
        diffText = ""
        diffTitle = ""
    }

    // MARK: - History Tab

    private var historyTab: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(gitService.commitLog) { commit in
                    commitRow(commit)
                    if commit.id != gitService.commitLog.last?.id {
                        Divider().padding(.leading, 24)
                    }
                }
            }
        }
    }

    private func commitRow(_ commit: GitCommit) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(commit.message)
                    .font(.caption)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(commit.shortHash)
                        .font(.caption2.monospaced())
                        .foregroundColor(.blue)
                    Text(commit.author)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(commit.date, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if commit.filesChanged > 0 {
                Text("\(commit.filesChanged) file\(commit.filesChanged == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(selectedCommit?.id == commit.id ? Color.accentColor.opacity(0.15) : Color.clear)
        .onTapGesture {
            selectedCommit = commit
        }
    }

    // MARK: - Footer

    private func openInGitApp() {
        guard let repo = selectedRepo else { return }
        guard let pref = configManager.settings.preferredGitApp else { return }

        if pref == .custom {
            guard let customPath = configManager.settings.customGitAppPath,
                  !customPath.isEmpty else { return }
            let appURL = URL(fileURLWithPath: customPath)
            NSWorkspace.shared.open(
                [repo.path],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else if let bundleId = pref.bundleIdentifier {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return }
            NSWorkspace.shared.open(
                [repo.path],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            Button {
                showRemoteSheet = true
            } label: {
                Image(systemName: gitService.remoteURL != nil ? "link" : "link.badge.plus")
            }
            .buttonStyle(.plain)
            .help(gitService.remoteURL != nil ? "Configure Remote" : "Add Remote")

            if let gitApp = configManager.settings.preferredGitApp {
                Button {
                    openInGitApp()
                } label: {
                    Label(gitApp.rawValue, systemImage: gitApp.icon)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(selectedRepo == nil)
                .help("Open in \(gitApp.rawValue)")
            }

            Spacer()

            Button {
                gitService.pull { success, output in
                    if success { gitService.refreshStatus() }
                    outputAlertTitle = success ? "Pull Successful" : "Pull Failed"
                    pushPullOutput = output.isEmpty ? (success ? "Already up to date." : "Unknown error") : output
                    showOutputAlert = true
                }
            } label: {
                Label("Pull", systemImage: "arrow.down.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(gitService.remoteURL == nil)

            Button {
                gitService.push { success, output in
                    if success { gitService.refreshStatus() }
                    outputAlertTitle = success ? "Push Successful" : "Push Failed"
                    pushPullOutput = output.isEmpty ? (success ? "Pushed successfully." : "Unknown error") : output
                    showOutputAlert = true
                }
            } label: {
                Label("Push", systemImage: "arrow.up.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .disabled(gitService.remoteURL == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Right Pane

    private var rightPane: some View {
        DiffView(diff: diffText, title: diffTitle)
    }

    // MARK: - Repo Loading

    @State private var isLoadingRepos = false

    private func loadRepositories() {
        isLoadingRepos = true
        let projects = configManager.loadProjects()
        let savedRepoPath = UserDefaults.standard.string(forKey: Self.selectedRepoKey)
        let customPaths = UserDefaults.standard.stringArray(forKey: Self.customReposKey) ?? []

        Task.detached {
            var repos: [GitRepository] = []

            // Check ~/.claude/ as a repo
            let claudeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
            if GitService.isGitRepository(at: claudeDir) {
                repos.append(GitRepository(
                    id: claudeDir.path,
                    path: claudeDir,
                    displayName: "~/.claude (Settings)",
                    isClaudeProject: true
                ))
            }

            // Check each Claude Code project for git repos
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            for project in projects {
                guard project.originalPath != home else { continue }
                let projectURL = URL(fileURLWithPath: project.originalPath)
                guard GitService.isGitRepository(at: projectURL) else { continue }
                guard !repos.contains(where: { $0.id == projectURL.path }) else { continue }
                repos.append(GitRepository(
                    id: projectURL.path,
                    path: projectURL,
                    displayName: project.displayName,
                    isClaudeProject: true
                ))
            }

            // Restore manually-added repos from previous sessions
            for path in customPaths {
                let url = URL(fileURLWithPath: path)
                guard !repos.contains(where: { $0.id == url.path }) else { continue }
                guard GitService.isGitRepository(at: url) else { continue }
                repos.append(GitRepository(
                    id: url.path,
                    path: url,
                    displayName: url.lastPathComponent,
                    isClaudeProject: false
                ))
            }

            await MainActor.run {
                repositories = repos
                isLoadingRepos = false

                // Restore previously selected repo
                if selectedRepo == nil, let saved = savedRepoPath,
                   let match = repos.first(where: { $0.path.path == saved }) {
                    selectedRepo = match
                }
                // Fallback: auto-select first if nothing saved
                else if selectedRepo == nil, let first = repos.first {
                    selectedRepo = first
                }
                // If user already has a selection, ensure it's still in the list
                else if let current = selectedRepo, !repos.contains(where: { $0.id == current.id }) {
                    selectedRepo = repos.first
                }
            }
        }
    }

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a git repository folder"
        panel.prompt = "Open"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Check if already in list
        if repositories.contains(where: { $0.id == url.path }) {
            selectedRepo = repositories.first(where: { $0.id == url.path })
            return
        }

        let repo = GitRepository(
            id: url.path,
            path: url,
            displayName: url.lastPathComponent,
            isClaudeProject: false
        )
        repositories.append(repo)
        selectedRepo = repo

        // Persist custom repo so it survives relaunch
        var customPaths = UserDefaults.standard.stringArray(forKey: Self.customReposKey) ?? []
        if !customPaths.contains(url.path) {
            customPaths.append(url.path)
            UserDefaults.standard.set(customPaths, forKey: Self.customReposKey)
        }
    }
}
