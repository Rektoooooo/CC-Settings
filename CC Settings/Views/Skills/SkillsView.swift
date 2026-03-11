import SwiftUI

// MARK: - Skill Models

struct Skill: Identifiable, Hashable {
    let id: String
    let name: String
    var description: String
    let path: URL
    let symlinkTarget: String?
    let isSymlink: Bool
    var files: [SkillFile]
    var scope: ConfigScope

    static func == (lhs: Skill, rhs: Skill) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var mainFile: SkillFile? {
        files.first(where: { $0.name.lowercased() == "skill.md" && $0.isRootLevel }) ??
        files.first(where: { $0.name.lowercased() == "readme.md" && $0.isRootLevel })
    }

    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

struct SkillFile: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let relativePath: String
    let type: SkillFileType
    let size: Int64
    let modificationDate: Date?
    let isRootLevel: Bool

    var isMainFile: Bool {
        isRootLevel && (name.lowercased() == "skill.md" || name.lowercased() == "readme.md")
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    static func == (lhs: SkillFile, rhs: SkillFile) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum SkillFileType: String, CaseIterable {
    case markdown
    case json
    case python
    case shell
    case text
    case pdf
    case other

    var icon: String {
        switch self {
        case .markdown: return "doc.richtext"
        case .json: return "curlybraces"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .shell: return "terminal"
        case .text: return "doc.text"
        case .pdf: return "doc.text.fill"
        case .other: return "doc"
        }
    }

    var color: Color {
        switch self {
        case .markdown: return .themeAccent
        case .json: return .orange
        case .python: return .green
        case .shell: return .purple
        case .text: return .gray
        case .pdf: return .red
        case .other: return .secondary
        }
    }

    var extensions: [String] {
        switch self {
        case .markdown: return ["md", "markdown"]
        case .json: return ["json"]
        case .python: return ["py", "python"]
        case .shell: return ["sh", "bash", "zsh"]
        case .text: return ["txt", "log", "conf", "config"]
        case .pdf: return ["pdf"]
        case .other: return []
        }
    }

    static func detect(from url: URL) -> SkillFileType {
        let ext = url.pathExtension.lowercased()
        for type in SkillFileType.allCases where type != .other {
            if type.extensions.contains(ext) {
                return type
            }
        }
        return .other
    }
}

// MARK: - SkillsView

struct SkillsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var skills: [Skill] = []
    @State private var selectedSkill: Skill?
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var scopeFilter: ScopeFilter = .all
    @State private var projects: [Project] = []

    private var globalSkillsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills")
    }

    private var availableScopes: [ConfigScope] {
        var scopes: [ConfigScope] = [.global]
        let seen = Set(skills.compactMap { s -> String? in
            if case .project(let id, _) = s.scope { return id }
            return nil
        })
        for project in projects {
            if seen.contains(project.id) {
                scopes.append(.project(id: project.id, path: project.originalPath))
            }
        }
        return scopes
    }

    private var filteredSkills: [Skill] {
        var result = skills

        switch scopeFilter {
        case .all: break
        case .global: result = result.filter { $0.scope.isGlobal }
        case .project(let id):
            result = result.filter {
                if case .project(let pid, _) = $0.scope { return pid == id }
                return false
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.scope.displayName.lowercased().contains(query)
            }
        }
        return result
    }

    var body: some View {
        HSplitView {
            // Left column - Skills list
            VStack(spacing: 0) {
                headerSection
                searchAndFilterSection
                Divider()
                skillsListSection
                Divider()
                footerSection
            }
            .frame(minWidth: 200, idealWidth: 300, maxWidth: 380)

            // Right column - Skill detail
            if let skill = selectedSkill,
               let current = skills.first(where: { $0.id == skill.id }) {
                SkillDetailView(skill: current)
            } else {
                EmptyContentPlaceholder(
                    icon: "sparkles",
                    title: "Select a Skill",
                    subtitle: "Choose a skill to view its contents"
                )
            }
        }
        .onAppear {
            loadSkills()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.themeAccent)
                    .font(.title3)
                Text("Skills")
                    .font(.headline)
                Spacer()
                Button {
                    loadSkills()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Reload")
            }
            Text("Global + Project skills")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
    }

    // MARK: - Search & Filter

    @ViewBuilder
    private var searchAndFilterSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search skills...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))

            if availableScopes.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ScopeFilterChip(label: "All", icon: "tray.2", isSelected: scopeFilter == .all) {
                            scopeFilter = .all
                        }
                        ScopeFilterChip(label: "Global", icon: "globe", isSelected: scopeFilter == .global) {
                            scopeFilter = .global
                        }
                        ForEach(availableScopes.filter { !$0.isGlobal }) { scope in
                            if case .project(let id, _) = scope {
                                ScopeFilterChip(label: scope.displayName, icon: "folder", isSelected: scopeFilter == .project(id: id)) {
                                    scopeFilter = .project(id: id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Skills List

    @ViewBuilder
    private var skillsListSection: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading skills...")
                .font(.caption)
            Spacer()
        } else if filteredSkills.isEmpty {
            Spacer()
            EmptyContentPlaceholder(
                icon: "sparkles",
                title: skills.isEmpty ? "No Skills" : "No Results",
                subtitle: skills.isEmpty ? "Skills will appear in ~/.claude/skills/ or project .claude/skills/" : "No skills match your search"
            )
            Spacer()
        } else {
            List(selection: $selectedSkill) {
                ForEach(filteredSkills) { skill in
                    SkillItemRow(skill: skill)
                        .tag(skill)
                        .contextMenu {
                            Button("Show in Finder") {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: skill.path.path)
                            }
                            if skill.isSymlink, let target = skill.symlinkTarget {
                                Button("Show Symlink Target") {
                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: target)
                                }
                            }
                        }
                }
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        HStack {
            Text("\(filteredSkills.count) skill\(filteredSkills.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            if scopeFilter != .all {
                Text("(filtered)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Data

    private func loadSkills() {
        isLoading = true
        projects = configManager.loadProjects()
        let fm = FileManager.default
        var loaded: [Skill] = []

        // Global skills
        loaded += loadSkillsFrom(url: globalSkillsURL, scope: .global, fm: fm)

        // Project skills
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for project in projects {
            guard project.originalPath != home else { continue }
            let projectSkillsURL = URL(fileURLWithPath: project.originalPath)
                .appendingPathComponent(".claude/skills")
            let scope = ConfigScope.project(id: project.id, path: project.originalPath)
            loaded += loadSkillsFrom(url: projectSkillsURL, scope: scope, fm: fm)
        }

        skills = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoading = false

        if let sel = selectedSkill, !skills.contains(where: { $0.id == sel.id }) {
            selectedSkill = nil
        }
    }

    private func loadSkillsFrom(url: URL, scope: ConfigScope, fm: FileManager) -> [Skill] {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [Skill] = []
        for itemURL in contents {
            let isSymlink = (try? itemURL.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
            let resolvedURL = isSymlink ? itemURL.resolvingSymlinksInPath() : itemURL
            let isDirectory = (try? resolvedURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

            let symlinkTarget: String? = isSymlink
                ? (try? fm.destinationOfSymbolicLink(atPath: itemURL.path))
                : nil

            if isDirectory {
                // Directory-based skill (standard layout with SKILL.md inside)
                let files = loadFilesRecursively(from: resolvedURL, basePath: resolvedURL)

                var description = ""
                let mainFile = files.first(where: { $0.name.lowercased() == "skill.md" && $0.isRootLevel }) ??
                               files.first(where: { $0.name.lowercased() == "readme.md" && $0.isRootLevel })
                if let mainFile = mainFile {
                    description = extractDescription(from: mainFile.path)
                }

                result.append(Skill(
                    id: itemURL.path,
                    name: itemURL.lastPathComponent,
                    description: description,
                    path: itemURL,
                    symlinkTarget: symlinkTarget,
                    isSymlink: isSymlink,
                    files: files,
                    scope: scope
                ))
            } else if itemURL.pathExtension.lowercased() == "md" {
                // Standalone .md file skill
                let name = itemURL.deletingPathExtension().lastPathComponent
                let attrs = try? itemURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let fileSize = Int64(attrs?.fileSize ?? 0)
                let description = extractDescription(from: itemURL)

                let file = SkillFile(
                    id: itemURL.path,
                    name: itemURL.lastPathComponent,
                    path: itemURL,
                    relativePath: itemURL.lastPathComponent,
                    type: .markdown,
                    size: fileSize,
                    modificationDate: attrs?.contentModificationDate,
                    isRootLevel: true
                )

                result.append(Skill(
                    id: itemURL.path,
                    name: name,
                    description: description,
                    path: itemURL,
                    symlinkTarget: symlinkTarget,
                    isSymlink: isSymlink,
                    files: [file],
                    scope: scope
                ))
            }
        }
        return result
    }

    private func loadFilesRecursively(from url: URL, basePath: URL) -> [SkillFile] {
        let fm = FileManager.default
        var result: [SkillFile] = []

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        while let fileURL = enumerator.nextObject() as? URL {
            guard (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true else {
                continue
            }
            let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let relativePath = fileURL.path.replacingOccurrences(of: basePath.path + "/", with: "")
            let isRootLevel = !relativePath.contains("/")

            result.append(SkillFile(
                id: fileURL.path,
                name: fileURL.lastPathComponent,
                path: fileURL,
                relativePath: relativePath,
                type: SkillFileType.detect(from: fileURL),
                size: Int64(attrs?.fileSize ?? 0),
                modificationDate: attrs?.contentModificationDate,
                isRootLevel: isRootLevel
            ))
        }

        return result.sorted { a, b in
            if a.isMainFile != b.isMainFile { return a.isMainFile }
            return a.relativePath.localizedCaseInsensitiveCompare(b.relativePath) == .orderedAscending
        }
    }

    private func extractDescription(from url: URL) -> String {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return "" }

        let lines = content.components(separatedBy: "\n")

        if content.hasPrefix("---") {
            var endIndex = -1
            for i in 1..<lines.count {
                if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                    endIndex = i
                    break
                }
            }
            if endIndex > 0 {
                for line in lines[1..<endIndex] {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("description:") {
                        return String(trimmed.dropFirst("description:".count)).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed == "---" { continue }
            return String(trimmed.prefix(100))
        }

        return ""
    }
}

// MARK: - SkillItemRow

private struct SkillItemRow: View {
    let skill: Skill

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: skill.isSymlink ? "link" : "sparkles")
                .foregroundColor(skill.isSymlink ? .orange : .themeAccent)
                .font(.body)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(skill.name)
                        .font(.body)
                        .lineLimit(1)
                    if skill.isSymlink {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    ScopeBadge(scope: skill.scope)
                    if !skill.description.isEmpty {
                        Text(skill.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - SkillDetailView

/// Combined detail view: file selector (when multiple files) + content viewer.
private struct SkillDetailView: View {
    let skill: Skill
    @State private var selectedFile: SkillFile?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: skill.isSymlink ? "link" : "sparkles")
                    .foregroundColor(skill.isSymlink ? .orange : .themeAccent)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(skill.name)
                        .font(.headline)
                        .lineLimit(1)
                    if skill.isSymlink, let target = skill.symlinkTarget {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                            Text(target)
                                .lineLimit(1)
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }

                ScopeBadge(scope: skill.scope)

                Spacer()

                // File picker (only when multiple files)
                if skill.files.count > 1 {
                    Picker("", selection: fileBinding) {
                        ForEach(skill.files) { file in
                            HStack(spacing: 4) {
                                Image(systemName: file.type.icon)
                                Text(file.relativePath)
                                if file.isMainFile {
                                    Text("(main)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tag(file as SkillFile?)
                        }
                    }
                    .frame(maxWidth: 200)
                }

                Text("\(skill.files.count) file\(skill.files.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(skill.formattedTotalSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassToolbar()

            // Content
            if let file = selectedFile {
                SkillFileViewer(file: file)
            } else {
                EmptyContentPlaceholder(
                    icon: "doc.text",
                    title: "No Files",
                    subtitle: "This skill has no viewable files"
                )
            }
        }
        .frame(minWidth: 400)
        .onAppear {
            selectedFile = skill.mainFile ?? skill.files.first
        }
        .onChange(of: skill.id) { _, _ in
            selectedFile = skill.mainFile ?? skill.files.first
        }
    }

    private var fileBinding: Binding<SkillFile?> {
        Binding(
            get: { selectedFile },
            set: { selectedFile = $0 }
        )
    }
}

// MARK: - SkillFileViewer

private struct SkillFileViewer: View {
    let file: SkillFile
    @State private var content: String = ""
    @State private var viewMode: ViewMode = .preview

    var body: some View {
        VStack(spacing: 0) {
            // Sub-toolbar for file-specific controls
            HStack(spacing: 8) {
                Image(systemName: file.type.icon)
                    .foregroundColor(file.type.color)
                    .font(.caption)

                Text(file.relativePath)
                    .font(.caption.monospaced())
                    .lineLimit(1)

                if file.isMainFile {
                    Text("MAIN")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.themeAccent)
                        .cornerRadius(3)
                }

                if file.type == .markdown {
                    ViewModePicker(mode: $viewMode)
                }

                Spacer()

                Text(file.formattedSize)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Content
            if file.type == .pdf {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("PDF Preview")
                        .font(.headline)
                    Text(file.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if file.type == .markdown {
                switch viewMode {
                case .source:
                    sourceView
                case .preview:
                    markdownPreviewView
                case .split:
                    HSplitView {
                        VStack(spacing: 0) {
                            PaneHeader(icon: "doc.text", title: "Source")
                            sourceView
                        }
                        VStack(spacing: 0) {
                            PaneHeader(icon: "eye", title: "Preview")
                            markdownPreviewView
                        }
                    }
                }
            } else if file.type == .json {
                jsonView
            } else {
                sourceView
            }
        }
        .onAppear {
            loadContent()
        }
        .onChange(of: file.id) { _, _ in
            loadContent()
        }
    }

    @ViewBuilder
    private var sourceView: some View {
        ScrollView {
            Text(content)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var markdownPreviewView: some View {
        ScrollView {
            MarkdownPreview(markdown: strippedContent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    @ViewBuilder
    private var jsonView: some View {
        ScrollView {
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
        }
    }

    /// Strip frontmatter from content for preview
    private var strippedContent: String {
        guard content.hasPrefix("---") else { return content }
        let lines = content.components(separatedBy: "\n")
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                let bodyLines = Array(lines[(i + 1)...])
                var body = bodyLines.joined(separator: "\n")
                if body.hasPrefix("\n") { body = String(body.dropFirst()) }
                return body
            }
        }
        return content
    }

    private func loadContent() {
        if let text = try? String(contentsOf: file.path, encoding: .utf8) {
            content = text
        } else {
            content = "[Unable to read file contents]"
        }
    }
}
