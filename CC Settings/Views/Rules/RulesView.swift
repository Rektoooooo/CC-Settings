import SwiftUI

// MARK: - Rule Model

struct RuleEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let scope: ConfigScope
    let size: Int64
    var content: String?
    var pathPatterns: [String]

    static func == (lhs: RuleEntry, rhs: RuleEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    /// Parse a rule .md file
    /// - Parameters:
    ///   - url: The file URL to parse
    ///   - scope: The config scope (global or project)
    ///   - nameOverride: Optional name override for nested rules (e.g. "subdir:rule")
    static func parse(from url: URL, scope: ConfigScope, nameOverride: String? = nil) -> RuleEntry? {
        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? Int64) ?? 0
        let name = nameOverride ?? url.deletingPathExtension().lastPathComponent

        let content = try? String(contentsOf: url, encoding: .utf8)
        var pathPatterns: [String] = []

        // Parse frontmatter for paths
        if let content = content, content.hasPrefix("---") {
            let lines = content.components(separatedBy: "\n")
            var endIndex = -1
            var inPaths = false
            for i in 1..<lines.count {
                let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
                if trimmed == "---" {
                    endIndex = i
                    break
                }
                if trimmed.hasPrefix("paths:") {
                    inPaths = true
                    continue
                }
                if inPaths {
                    if trimmed.hasPrefix("- ") {
                        let pattern = String(trimmed.dropFirst(2))
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                        pathPatterns.append(pattern)
                    } else if !trimmed.isEmpty {
                        inPaths = false
                    }
                }
            }
            _ = endIndex // suppress unused warning
        }

        return RuleEntry(
            id: url.path,
            name: name,
            path: url,
            scope: scope,
            size: fileSize,
            content: content,
            pathPatterns: pathPatterns
        )
    }
}

// MARK: - RulesView

struct RulesView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var rules: [RuleEntry] = []
    @State private var selectedRule: RuleEntry?
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var scopeFilter: ScopeFilter = .all
    @State private var projects: [Project] = []

    private var globalRulesURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/rules")
    }

    private var availableScopes: [ConfigScope] {
        var scopes: [ConfigScope] = [.global]
        let seen = Set(rules.compactMap { r -> String? in
            if case .project(let id, _) = r.scope { return id }
            return nil
        })
        for project in projects {
            if seen.contains(project.id) {
                scopes.append(.project(id: project.id, path: project.originalPath))
            }
        }
        return scopes
    }

    private var filteredRules: [RuleEntry] {
        var result = rules

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
                $0.scope.displayName.lowercased().contains(query) ||
                $0.pathPatterns.contains { $0.lowercased().contains(query) }
            }
        }
        return result
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                headerSection
                searchAndFilterSection
                Divider()
                rulesListSection
                Divider()
                footerSection
            }
            .frame(minWidth: 200, idealWidth: 300, maxWidth: 380)

            if let rule = selectedRule,
               let current = rules.first(where: { $0.id == rule.id }) {
                RuleDetailView(rule: current)
            } else {
                EmptyContentPlaceholder(
                    icon: "list.bullet.rectangle",
                    title: "Select a Rule",
                    subtitle: "Choose a rule to view its contents"
                )
            }
        }
        .onAppear {
            loadRules()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.themeAccent)
                    .font(.title3)
                Text("Rules")
                    .font(.headline)
                Spacer()
                Button {
                    loadRules()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Reload")
            }
            Text("Global + Project rules")
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
                TextField("Search rules...", text: $searchText)
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

    // MARK: - Rules List

    @ViewBuilder
    private var rulesListSection: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading rules...")
                .font(.caption)
            Spacer()
        } else if filteredRules.isEmpty {
            Spacer()
            EmptyContentPlaceholder(
                icon: "list.bullet.rectangle",
                title: rules.isEmpty ? "No Rules" : "No Results",
                subtitle: rules.isEmpty ? "Rules will appear in ~/.claude/rules/ or project .claude/rules/" : "No rules match your search"
            )
            Spacer()
        } else {
            List(selection: $selectedRule) {
                ForEach(filteredRules) { rule in
                    RuleItemRow(rule: rule)
                        .tag(rule)
                        .contextMenu {
                            Button("Show in Finder") {
                                NSWorkspace.shared.selectFile(rule.path.path, inFileViewerRootedAtPath: rule.path.deletingLastPathComponent().path)
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
            Text("\(filteredRules.count) rule\(filteredRules.count == 1 ? "" : "s")")
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

    private func loadRules() {
        isLoading = true
        projects = configManager.loadProjects()
        let fm = FileManager.default
        var loaded: [RuleEntry] = []

        loaded += loadRulesFrom(url: globalRulesURL, scope: .global, fm: fm)

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for project in projects {
            guard project.originalPath != home else { continue }
            let projectRulesURL = URL(fileURLWithPath: project.originalPath)
                .appendingPathComponent(".claude/rules")
            let scope = ConfigScope.project(id: project.id, path: project.originalPath)
            loaded += loadRulesFrom(url: projectRulesURL, scope: scope, fm: fm)
        }

        rules = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoading = false

        if let sel = selectedRule, !rules.contains(where: { $0.id == sel.id }) {
            selectedRule = nil
        }
    }

    private func loadRulesFrom(url: URL, scope: ConfigScope, fm: FileManager) -> [RuleEntry] {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [RuleEntry] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            // Build the rule name from the relative path within the rules directory
            // e.g. "subdir/rule.md" becomes "subdir:rule"
            let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
            let name = relativePath
                .replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "/", with: ":")
            if let rule = RuleEntry.parse(from: fileURL, scope: scope, nameOverride: name) {
                results.append(rule)
            }
        }
        return results
    }
}

// MARK: - RuleItemRow

private struct RuleItemRow: View {
    let rule: RuleEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .foregroundColor(.themeAccent)
                .font(.body)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    ScopeBadge(scope: rule.scope)
                    if !rule.pathPatterns.isEmpty {
                        Text("\(rule.pathPatterns.count) path\(rule.pathPatterns.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - RuleDetailView

private struct RuleDetailView: View {
    let rule: RuleEntry
    @State private var viewMode: ViewMode = .preview

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.themeAccent)
                    .font(.title3)

                Text(rule.name)
                    .font(.headline)
                    .lineLimit(1)

                ScopeBadge(scope: rule.scope)

                ViewModePicker(mode: $viewMode)

                Spacer()

                Text(rule.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassToolbar()

            // Path patterns
            if !rule.pathPatterns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Path Patterns")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    FlowLayout(spacing: 4) {
                        ForEach(rule.pathPatterns, id: \.self) { pattern in
                            Text(pattern)
                                .font(.caption2.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.themeAccent.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider()
            }

            // Content
            if let content = rule.content {
                switch viewMode {
                case .source:
                    ScrollView {
                        Text(content)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .textSelection(.enabled)
                    }
                case .preview:
                    ScrollView {
                        MarkdownPreview(markdown: strippedContent(content))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                case .split:
                    HSplitView {
                        VStack(spacing: 0) {
                            PaneHeader(icon: "doc.text", title: "Source")
                            ScrollView {
                                Text(content)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .textSelection(.enabled)
                            }
                        }
                        VStack(spacing: 0) {
                            PaneHeader(icon: "eye", title: "Preview")
                            ScrollView {
                                MarkdownPreview(markdown: strippedContent(content))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                            }
                        }
                    }
                }
            } else {
                EmptyContentPlaceholder(
                    icon: "doc.text",
                    title: "Unable to Read",
                    subtitle: "Could not read the rule file"
                )
            }
        }
        .frame(minWidth: 400)
    }

    private func strippedContent(_ content: String) -> String {
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
}
