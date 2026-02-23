import SwiftUI

struct ClaudeMDEditorView: View {
    @EnvironmentObject var configManager: ConfigurationManager

    @State private var content: String = ""
    @State private var originalContent: String = ""
    @State private var viewMode: ViewMode = .source
    @State private var selectedScope: String = "global"
    @State private var projects: [Project] = []
    @State private var showTemplateSheet = false
    @State private var showInsertPopover = false
    @State private var hasLoadedInitial = false
    @State private var isCreating = false

    private var hasChanges: Bool {
        content != originalContent
    }

    private var isGlobal: Bool {
        selectedScope == "global"
    }

    private var currentProject: Project? {
        projects.first(where: { $0.id == selectedScope })
    }

    private var hasContent: Bool {
        if isCreating { return true }
        if isGlobal {
            return !configManager.claudeMD.isEmpty || !content.isEmpty
        } else {
            return currentProject?.claudeMD != nil || !content.isEmpty
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            editorContent
        }
        .onAppear {
            loadProjects()
            loadContent()
            hasLoadedInitial = true
        }
        .onChange(of: selectedScope) { _, _ in
            if hasLoadedInitial {
                loadContent()
            }
        }
        .sheet(isPresented: $showTemplateSheet) {
            ClaudeMDTemplateSheet { templateContent in
                isCreating = true
                content = templateContent
                originalContent = ""
            }
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.richtext")
                .foregroundColor(.blue)
                .font(.title3)

            Text("CLAUDE.md")
                .font(.headline)

            // Scope picker
            Picker("Scope", selection: $selectedScope) {
                Label("Global (~/.claude/)", systemImage: "globe").tag("global")

                if !filteredProjects.isEmpty {
                    Divider()
                    ForEach(filteredProjects) { project in
                        HStack {
                            Text(project.displayName)
                            if project.claudeMD != nil {
                                Text("(has CLAUDE.md)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(project.id)
                    }
                }
            }
            .frame(minWidth: 180)

            ViewModePicker(mode: $viewMode)

            Spacer()

            if hasContent {
                // Insert button
                Button {
                    showInsertPopover.toggle()
                } label: {
                    Label("Insert", systemImage: "plus.square")
                }
                .popover(isPresented: $showInsertPopover) {
                    ClaudeMDInsertMenu(content: $content)
                }

                if hasChanges {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                        .help("Unsaved changes")

                    Button("Revert") {
                        content = originalContent
                    }
                }

                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!hasChanges)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassToolbar()
    }

    // MARK: - Editor Content

    @ViewBuilder
    private var editorContent: some View {
        if hasContent {
            switch viewMode {
            case .source:
                sourceView
            case .preview:
                previewView
            case .split:
                HSplitView {
                    VStack(spacing: 0) {
                        PaneHeader(icon: "doc.text", title: "Source")
                        sourceView
                    }
                    VStack(spacing: 0) {
                        PaneHeader(icon: "eye", title: "Preview")
                        previewView
                    }
                }
            }
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private var sourceView: some View {
        TextEditor(text: $content)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var previewView: some View {
        ScrollView {
            if content.isEmpty {
                EmptyContentPlaceholder(
                    icon: "doc.text",
                    title: "No Content",
                    subtitle: "Start typing in the source view"
                )
            } else {
                MarkdownPreview(markdown: content)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No CLAUDE.md")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(isGlobal
                ? "Create a global CLAUDE.md to provide instructions across all projects."
                : "Create a CLAUDE.md for this project.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            HStack(spacing: 12) {
                Button("Create from Template") {
                    isCreating = true
                    showTemplateSheet = true
                }

                Button("Create Blank") {
                    isCreating = true
                    content = "# CLAUDE.md\n\n"
                    originalContent = ""
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filtered Projects

    private var filteredProjects: [Project] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return projects.filter { project in
            guard project.originalPath != home else { return false }
            let hasClaudeMD = project.claudeMD != nil
            let hasSessions = !project.sessions.isEmpty
            let hasSettings = project.settings != nil
            return hasClaudeMD || hasSessions || hasSettings
        }
    }

    // MARK: - Load / Save

    private func loadProjects() {
        projects = configManager.loadProjects()
    }

    private func loadContent() {
        isCreating = false
        if isGlobal {
            content = configManager.claudeMD
            originalContent = configManager.claudeMD
        } else {
            let loaded = configManager.loadProjectClaudeMD(projectId: selectedScope) ?? ""
            content = loaded
            originalContent = loaded
        }
    }

    private func save() {
        if isGlobal {
            configManager.claudeMD = content
            configManager.saveClaudeMD()
            originalContent = content
        } else {
            configManager.saveProjectClaudeMD(content, projectId: selectedScope)
            originalContent = content
            // Reload projects to pick up changes
            loadProjects()
        }
    }
}
