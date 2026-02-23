import SwiftUI

// MARK: - Plugin Models

struct Marketplace: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let owner: String
    let ownerEmail: String
    let source: String
    let installPath: String
    let lastUpdated: Date?
    var plugins: [Plugin]

    static func == (lhs: Marketplace, rhs: Marketplace) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Plugin: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let version: String
    let author: String
    let authorEmail: String
    let category: String
    let keywords: [String]
    let source: String
    let isExternal: Bool
    let path: String
    let readme: String
    let marketplaceName: String
    var skills: [PluginSkill]
    var commands: [PluginCommand]

    static func == (lhs: Plugin, rhs: Plugin) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct PluginSkill: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
}

struct PluginCommand: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private struct ArrangeResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return ArrangeResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: totalHeight)
        )
    }
}

// MARK: - PluginsView

struct PluginsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var marketplaces: [Marketplace] = []
    @State private var selectedPlugin: Plugin?
    @State private var searchText = ""
    @State private var isLoading = false

    private let pluginsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/plugins").path
    }()

    private var pluginsURL: URL {
        URL(fileURLWithPath: pluginsPath)
    }

    private var allPlugins: [Plugin] {
        marketplaces.flatMap { $0.plugins }
    }

    private var totalPluginCount: Int {
        allPlugins.count
    }

    /// Filter plugins across all marketplaces
    private func filteredPlugins(for marketplace: Marketplace) -> [Plugin] {
        if searchText.isEmpty {
            return marketplace.plugins
        }
        let query = searchText.lowercased()
        return marketplace.plugins.filter {
            $0.name.lowercased().contains(query) ||
            $0.description.lowercased().contains(query) ||
            $0.keywords.contains(where: { $0.lowercased().contains(query) }) ||
            $0.category.lowercased().contains(query)
        }
    }

    private var hasAnyFilteredResults: Bool {
        marketplaces.contains { !filteredPlugins(for: $0).isEmpty }
    }

    var body: some View {
        HSplitView {
            // Left column - Plugins list (grouped by marketplace)
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "puzzlepiece")
                            .foregroundColor(.themeAccent)
                            .font(.title3)
                        Text("Plugins")
                            .font(.headline)
                        Spacer()
                        Button {
                            loadMarketplaces()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .help("Reload")
                    }
                    Text("~/.claude/plugins")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding(12)

                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search plugins...", text: $searchText)
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
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                Divider()

                // Plugin list grouped by marketplace
                if isLoading {
                    Spacer()
                    ProgressView("Loading plugins...")
                        .font(.caption)
                    Spacer()
                } else if marketplaces.isEmpty {
                    Spacer()
                    EmptyContentPlaceholder(
                        icon: "puzzlepiece",
                        title: "No Plugins",
                        subtitle: "No plugin marketplaces found"
                    )
                    Spacer()
                } else if !hasAnyFilteredResults {
                    Spacer()
                    EmptyContentPlaceholder(
                        icon: "puzzlepiece",
                        title: "No Results",
                        subtitle: "No plugins match your search"
                    )
                    Spacer()
                } else {
                    List(selection: $selectedPlugin) {
                        ForEach(marketplaces) { marketplace in
                            let filtered = filteredPlugins(for: marketplace)
                            if !filtered.isEmpty {
                                Section {
                                    ForEach(filtered) { plugin in
                                        PluginItemRow(plugin: plugin)
                                            .tag(plugin)
                                            .contextMenu {
                                                Button("Show in Finder") {
                                                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: plugin.path)
                                                }
                                                Button("Copy Install Command") {
                                                    NSPasteboard.general.clearContents()
                                                    NSPasteboard.general.setString(
                                                        "/plugin install \(plugin.name)@\(plugin.marketplaceName)",
                                                        forType: .string
                                                    )
                                                }
                                            }
                                    }
                                } header: {
                                    HStack(spacing: 4) {
                                        Text(marketplace.name)
                                            .font(.caption.bold())
                                        Text("\(filtered.count)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }

                Divider()

                // Footer
                HStack {
                    Text("\(totalPluginCount) plugin\(totalPluginCount == 1 ? "" : "s") in \(marketplaces.count) marketplace\(marketplaces.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .frame(minWidth: 220, idealWidth: 320, maxWidth: 420)

            // Right column - Plugin detail
            if let plugin = selectedPlugin {
                PluginDetailView(plugin: plugin)
            } else {
                EmptyContentPlaceholder(
                    icon: "puzzlepiece",
                    title: "Select a Plugin",
                    subtitle: "Choose a plugin to view details"
                )
            }
        }
        .onAppear {
            loadMarketplaces()
        }
    }

    // MARK: - Data Loading

    private func loadMarketplaces() {
        isLoading = true
        let fm = FileManager.default
        var loaded: [Marketplace] = []

        let knownURL = pluginsURL.appendingPathComponent("known_marketplaces.json")
        guard let data = try? Data(contentsOf: knownURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            marketplaces = []
            isLoading = false
            return
        }

        for (marketplaceName, value) in json {
            guard let entry = value as? [String: Any],
                  let installLocation = entry["installLocation"] as? String else { continue }
            let installURL = URL(fileURLWithPath: installLocation)

            let marketplaceJSON = installURL.appendingPathComponent(".claude-plugin/marketplace.json")
            var name = marketplaceName
            var description = ""
            var owner = ""
            var ownerEmail = ""
            var source = ""
            var plugins: [Plugin] = []
            var lastUpdated: Date?

            if let dateStr = entry["lastUpdated"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                lastUpdated = formatter.date(from: dateStr)
            }

            if let mData = try? Data(contentsOf: marketplaceJSON),
               let mJSON = try? JSONSerialization.jsonObject(with: mData) as? [String: Any] {
                name = mJSON["name"] as? String ?? name
                description = mJSON["description"] as? String ?? description
                if let ownerStr = mJSON["owner"] as? String {
                    owner = ownerStr
                } else if let ownerObj = mJSON["owner"] as? [String: Any] {
                    owner = ownerObj["name"] as? String ?? owner
                    ownerEmail = ownerObj["email"] as? String ?? ownerEmail
                }
                if let sourceStr = mJSON["source"] as? String {
                    source = sourceStr
                }

                if let pluginsArray = mJSON["plugins"] as? [[String: Any]] {
                    for pJSON in pluginsArray {
                        if let plugin = parsePlugin(from: pJSON, basePath: installURL.path, isExternal: false, marketplaceName: name) {
                            plugins.append(plugin)
                        }
                    }
                }
            }

            let pluginsSubdir = installURL.appendingPathComponent("plugins")
            if let contents = try? fm.contentsOfDirectory(
                at: pluginsSubdir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for dir in contents {
                    guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                    let pluginJSON = dir.appendingPathComponent(".claude-plugin/plugin.json")
                    if let pData = try? Data(contentsOf: pluginJSON),
                       let pJSON = try? JSONSerialization.jsonObject(with: pData) as? [String: Any] {
                        if let plugin = parsePlugin(from: pJSON, basePath: dir.path, isExternal: true, marketplaceName: name) {
                            if !plugins.contains(where: { $0.name == plugin.name }) {
                                plugins.append(plugin)
                            }
                        }
                    }
                }
            }

            let attrs = try? fm.attributesOfItem(atPath: installURL.path)
            lastUpdated = attrs?[.modificationDate] as? Date

            loaded.append(Marketplace(
                id: installLocation,
                name: name,
                description: description,
                owner: owner,
                ownerEmail: ownerEmail,
                source: source,
                installPath: installLocation,
                lastUpdated: lastUpdated,
                plugins: plugins.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            ))
        }

        marketplaces = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoading = false

        // Auto-select first plugin
        if selectedPlugin == nil {
            selectedPlugin = allPlugins.first
        }
    }

    private func parsePlugin(from json: [String: Any], basePath: String, isExternal: Bool, marketplaceName: String) -> Plugin? {
        let name = json["name"] as? String ?? "Unknown"
        let id = json["id"] as? String ?? "\(basePath)/\(name)"

        var pluginDir = basePath
        if let sourceStr = json["source"] as? String, sourceStr.hasPrefix("./") {
            pluginDir = URL(fileURLWithPath: basePath).appendingPathComponent(sourceStr).path
        }

        var readme = ""
        let readmeURL = URL(fileURLWithPath: pluginDir).appendingPathComponent("README.md")
        if let content = try? String(contentsOf: readmeURL, encoding: .utf8) {
            readme = content
        }

        var skills: [PluginSkill] = []
        if let skillsArray = json["skills"] as? [[String: Any]] {
            for sJSON in skillsArray {
                skills.append(PluginSkill(
                    id: sJSON["name"] as? String ?? UUID().uuidString,
                    name: sJSON["name"] as? String ?? "Unknown",
                    description: sJSON["description"] as? String ?? ""
                ))
            }
        }

        var commands: [PluginCommand] = []
        if let commandsArray = json["commands"] as? [[String: Any]] {
            for cJSON in commandsArray {
                commands.append(PluginCommand(
                    id: cJSON["name"] as? String ?? UUID().uuidString,
                    name: cJSON["name"] as? String ?? "Unknown",
                    description: cJSON["description"] as? String ?? ""
                ))
            }
        }

        var authorName = ""
        var authorEmail = ""
        if let authorStr = json["author"] as? String {
            authorName = authorStr
        } else if let authorObj = json["author"] as? [String: Any] {
            authorName = authorObj["name"] as? String ?? ""
            authorEmail = authorObj["email"] as? String ?? ""
        }

        var sourceStr = ""
        if let s = json["source"] as? String {
            sourceStr = s
        } else if let sObj = json["source"] as? [String: Any] {
            sourceStr = sObj["url"] as? String ?? sObj["repo"] as? String ?? ""
        }

        return Plugin(
            id: id,
            name: name,
            description: json["description"] as? String ?? "",
            version: json["version"] as? String ?? "0.0.0",
            author: authorName,
            authorEmail: authorEmail,
            category: json["category"] as? String ?? "",
            keywords: json["keywords"] as? [String] ?? [],
            source: sourceStr,
            isExternal: isExternal,
            path: basePath,
            readme: readme,
            marketplaceName: marketplaceName,
            skills: skills,
            commands: commands
        )
    }
}

// MARK: - PluginItemRow

private struct PluginItemRow: View {
    let plugin: Plugin

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(plugin.name)
                    .font(.body)
                    .lineLimit(1)
                Text(plugin.version)
                    .font(.caption2.monospaced())
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.themeAccent.opacity(0.8))
                    .cornerRadius(3)
                if !plugin.category.isEmpty {
                    Text(plugin.category)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            if !plugin.description.isEmpty {
                Text(plugin.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - PluginDetailView

private struct PluginDetailView: View {
    let plugin: Plugin
    @State private var viewMode: ViewMode = .preview

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Image(systemName: "puzzlepiece")
                    .foregroundColor(.themeAccent)
                    .font(.title3)

                Text(plugin.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(plugin.version)
                    .font(.caption.monospaced())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.themeAccent)
                    .cornerRadius(4)

                if !plugin.category.isEmpty {
                    Text(plugin.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }

                Spacer()

                if !plugin.readme.isEmpty {
                    ViewModePicker(mode: $viewMode)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassToolbar()

            // Content
            if !plugin.readme.isEmpty && viewMode == .split {
                HSplitView {
                    VStack(spacing: 0) {
                        PaneHeader(icon: "doc.text", title: "Source")
                        sourceView
                    }
                    VStack(spacing: 0) {
                        PaneHeader(icon: "eye", title: "Preview")
                        previewScrollView
                    }
                }
            } else if !plugin.readme.isEmpty && viewMode == .source {
                sourceView
            } else {
                previewScrollView
            }
        }
        .frame(minWidth: 400)
    }

    @ViewBuilder
    private var sourceView: some View {
        ScrollView {
            Text(plugin.readme)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var previewScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Compact info row
                pluginInfoSection

                // Skills & Commands
                if !plugin.skills.isEmpty || !plugin.commands.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if !plugin.skills.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Skills (\(plugin.skills.count))")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                ForEach(plugin.skills) { skill in
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkle")
                                            .foregroundColor(.themeAccent)
                                            .font(.caption2)
                                        Text(skill.name)
                                            .font(.caption.monospaced())
                                        if !skill.description.isEmpty {
                                            Text(skill.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }

                        if !plugin.commands.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Commands (\(plugin.commands.count))")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                ForEach(plugin.commands) { command in
                                    HStack(spacing: 6) {
                                        Image(systemName: "terminal")
                                            .foregroundColor(.themeAccent)
                                            .font(.caption2)
                                        Text("/\(command.name)")
                                            .font(.caption.monospaced())
                                        if !command.description.isEmpty {
                                            Text(command.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // README
                if !plugin.readme.isEmpty {
                    Divider()
                    MarkdownPreview(markdown: plugin.readme)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var pluginInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Info as compact rows
            HStack(spacing: 16) {
                if !plugin.author.isEmpty {
                    HStack(spacing: 4) {
                        Text("Author")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(plugin.author)
                            .font(.caption)
                    }
                }
                if !plugin.source.isEmpty {
                    HStack(spacing: 4) {
                        Text("Source")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(plugin.source)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            // Keywords
            if !plugin.keywords.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(plugin.keywords, id: \.self) { keyword in
                        Text(keyword)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.themeAccent.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
        }
    }

}
