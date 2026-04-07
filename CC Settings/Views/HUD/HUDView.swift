import SwiftUI

// MARK: - HUD Config Model

/// Represents the claude-hud plugin configuration at ~/.claude/plugins/claude-hud/config.json
/// The plugin expects usage fields inside `display`, and `autocompactBuffer` as "enabled"/"disabled".
struct HUDConfig: Codable, Equatable {
    var language: String
    var display: HUDDisplayConfig
    var lineLayout: String
    var showSeparators: Bool
    var pathLevels: Int
    var elementOrder: [String]
    var gitStatus: HUDGitConfig
    var colors: HUDColorOverrides
    /// User-defined named colors (name → hex string like "#ff6600")
    var customColors: [String: String]

    static let allElementKeys = ["project", "context", "usage", "memory", "environment", "tools", "agents", "todos"]

    init() {
        language = "en"
        display = HUDDisplayConfig()
        lineLayout = "expanded"
        showSeparators = false
        pathLevels = 1
        elementOrder = Self.allElementKeys
        gitStatus = HUDGitConfig()
        colors = HUDColorOverrides()
        customColors = [:]
    }

    struct HUDDisplayConfig: Codable, Equatable {
        var showModel: Bool = true
        var showProject: Bool = true
        var showContextBar: Bool = true
        var contextValue: String = "percent"
        var showTokenBreakdown: Bool = true
        var showConfigCounts: Bool = false
        var showCost: Bool = false
        var showDuration: Bool = false
        var showSpeed: Bool = false
        var showUsage: Bool = true
        var usageBarEnabled: Bool = true
        var showTools: Bool = false
        var showAgents: Bool = false
        var showTodos: Bool = false
        var showSessionName: Bool = false
        var showClaudeCodeVersion: Bool = false
        var showMemoryUsage: Bool = false
        var showSessionTokens: Bool = false
        var showOutputStyle: Bool = false
        var autocompactBuffer: String = "enabled"
        var usageThreshold: Int = 0
        var sevenDayThreshold: Int = 80
        var environmentThreshold: Int = 0
        var modelFormat: String = "full"
        var modelOverride: String = ""
        var customLine: String = ""
    }

    struct HUDGitConfig: Codable, Equatable {
        var enabled: Bool = true
        var showDirty: Bool = true
        var showAheadBehind: Bool = false
        var showFileStats: Bool = false
        var pushWarningThreshold: Int = 0
        var pushCriticalThreshold: Int = 0
    }

    struct HUDColorOverrides: Codable, Equatable {
        var context: String = "green"
        var usage: String = "brightBlue"
        var warning: String = "yellow"
        var usageWarning: String = "brightMagenta"
        var critical: String = "red"
        var model: String = "cyan"
        var project: String = "yellow"
        var git: String = "magenta"
        var gitBranch: String = "cyan"
        var label: String = "dim"
        var custom: String = "208"
    }
}

// MARK: - Element Item

struct ElementItem: Identifiable, Equatable {
    let id: String
    var isEnabled: Bool

    var label: String {
        switch id {
        case "project": return "Project"
        case "context": return "Context Bar"
        case "usage": return "Usage"
        case "memory": return "Memory"
        case "environment": return "Environment"
        case "tools": return "Tools"
        case "agents": return "Agents"
        case "todos": return "Todos"
        default: return id
        }
    }

    var icon: String {
        switch id {
        case "project": return "folder"
        case "context": return "chart.bar"
        case "usage": return "gauge.medium"
        case "memory": return "brain"
        case "environment": return "gearshape.2"
        case "tools": return "wrench.and.screwdriver"
        case "agents": return "person.2"
        case "todos": return "checklist"
        default: return "questionmark"
        }
    }
}

// MARK: - Installed Plugins Model

private struct InstalledPlugins: Codable {
    var version: Int?
    var plugins: [String: [PluginEntry]]?

    struct PluginEntry: Codable {
        var version: String?
        var installPath: String?
    }
}

// MARK: - HUDView

struct HUDView: View {
    @State private var config = HUDConfig()
    @State private var isInstalled = false
    @State private var installedVersion: String?
    @State private var hasLoadedOnce = false
    @State private var allElements: [ElementItem] = []
    @State private var draggedElementID: String?
    @State private var hoveredElementID: String?
    @State private var newColorName: String = ""
    @State private var newColorPick: Color = .orange
    @State private var showingAddColor = false

    /// Hardcoded path matching the claude-hud plugin's expected config location.
    /// This is the canonical path used by the plugin itself; deriving it from install
    /// metadata would add complexity without benefit since the plugin always reads from here.
    private let configURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/plugins/claude-hud/config.json")
    }()

    var body: some View {
        Form {
            statusBannerSection
            previewSection
            layoutSection
            displaySection
            usageSection
            activitySection
            gitStatusSection
            colorsSection
            customColorsSection
            presetsSection
            creditSection
        }
        .formStyle(.grouped)
        .navigationTitle("HUD")
        .onAppear {
            checkInstallation()
            loadConfig()
            buildElementItems()
        }
    }

    // MARK: - Status Banner

    private var statusBannerSection: some View {
        Section {
            if isInstalled {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("claude-hud is installed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let version = installedVersion {
                            Text("Version \(version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("claude-hud is not installed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Install with: /install-plugin claude-hud@claude-hud")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: - Live Preview

    private var previewSection: some View {
        Section {
            if config.lineLayout == "expanded" {
                expandedPreviewContent
            } else {
                Text(buildPreview())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineSpacing(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        } header: {
            Text("Preview")
        } footer: {
            Text(config.lineLayout == "expanded"
                ? "Drag to reorder elements. Toggle visibility in Display and Activity sections."
                : "Live preview of how the HUD will appear in Claude Code.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var expandedPreviewContent: some View {
        let gitSuffix = buildGitSuffix()
        let visible = visibleElements
        let activityKeys: Set<String> = ["tools", "agents", "todos"]
        let headerElements = visible.filter { !activityKeys.contains($0.id) }
        let activityElements = visible.filter { activityKeys.contains($0.id) }

        VStack(alignment: .leading, spacing: 0) {
            if visible.isEmpty {
                Text("(nothing to display)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                let pairKeys: Set<String> = ["context", "usage"]

                ForEach(headerElements) { element in
                    let idx = headerElements.firstIndex(where: { $0.id == element.id })!
                    let isFirstOfPair = pairKeys.contains(element.id)
                        && idx + 1 < headerElements.count
                        && pairKeys.contains(headerElements[idx + 1].id)
                    let isSecondOfPair = pairKeys.contains(element.id)
                        && idx > 0
                        && pairKeys.contains(headerElements[idx - 1].id)

                    if isFirstOfPair {
                        combinedPreviewRow(first: element, second: headerElements[idx + 1], gitSuffix: gitSuffix)
                    } else if isSecondOfPair {
                        EmptyView()
                    } else {
                        previewRowView(for: element, gitSuffix: gitSuffix)
                    }
                }

                if config.showSeparators && !headerElements.isEmpty && !activityElements.isEmpty {
                    Text(String(repeating: "\u{2500}", count: 35))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                }

                ForEach(activityElements) { element in
                    previewRowView(for: element, gitSuffix: gitSuffix)
                }
            }
        }
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func previewRowView(for element: ElementItem, gitSuffix: String) -> some View {
        previewElementView(for: element, content: coloredPreviewText(for: element.id, gitSuffix: gitSuffix))
    }

    @ViewBuilder
    private func combinedPreviewRow(first: ElementItem, second: ElementItem, gitSuffix: String) -> some View {
        HStack(spacing: 0) {
            previewElementView(for: first, content: coloredPreviewText(for: first.id, gitSuffix: gitSuffix), inline: true)
            Text(" \u{2502} ")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            previewElementView(for: second, content: coloredPreviewText(for: second.id, gitSuffix: gitSuffix), inline: true)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func previewElementView(for element: ElementItem, content: Text?, inline: Bool = false) -> some View {
        if let content = content {
            content
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, inline ? 4 : 10)
                .padding(.vertical, 3)
                .frame(maxWidth: inline ? nil : .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hoveredElementID == element.id ? Color.primary.opacity(0.06) : Color.clear)
                )
                .opacity(draggedElementID == element.id ? 0.4 : 1.0)
                .onHover { hovering in
                    hoveredElementID = hovering ? element.id : nil
                }
                .onDrag {
                    draggedElementID = element.id
                    return NSItemProvider(object: element.id as NSString)
                }
                .onDrop(of: [.text], delegate: PreviewDropDelegate(
                    item: element,
                    allElements: $allElements,
                    draggedElementID: $draggedElementID,
                    onReorder: syncElementOrder
                ))
        }
    }

    // MARK: - Colored Preview Text

    private let pf = Font.system(size: 11, design: .monospaced)

    private func coloredPreviewText(for elementID: String, gitSuffix: String) -> Text? {
        let dim = swiftUIColor(for: config.colors.label)

        switch elementID {
        case "project":
            guard config.display.showModel || config.display.showProject else { return nil }
            var parts: [Text] = []
            if config.display.showModel {
                let modelColor = swiftUIColor(for: config.colors.model)
                let name: String
                switch config.display.modelFormat {
                case "short": name = "Opus 4.6"
                case "compact": name = "Opus 4.6"
                default: name = "Opus 4.6 (1M context)"
                }
                let display = config.display.modelOverride.isEmpty ? "\(name) | Max" : config.display.modelOverride
                parts.append(Text("[\(display)]").font(pf).foregroundColor(modelColor))
            }
            if config.display.showProject {
                let projColor = swiftUIColor(for: config.colors.project)
                let gitColor = swiftUIColor(for: config.colors.git)
                let branchColor = swiftUIColor(for: config.colors.gitBranch)
                parts.append(Text("my-project").font(pf).foregroundColor(projColor))
                if config.gitStatus.enabled {
                    var branch = "main"
                    if config.gitStatus.showDirty { branch += "*" }
                    parts.append(Text(" git:(").font(pf).foregroundColor(gitColor)
                                 + Text(branch).font(pf).foregroundColor(branchColor)
                                 + Text(")").font(pf).foregroundColor(gitColor))
                    if config.gitStatus.showAheadBehind {
                        parts.append(Text(" \u{2191}2 \u{2193}1").font(pf).foregroundColor(branchColor))
                    }
                }
            }
            if config.display.showSessionName { parts.append(Text("precious-hollerith").font(pf).foregroundColor(dim)) }
            if config.display.showClaudeCodeVersion { parts.append(Text("CC v2.1.92").font(pf).foregroundColor(dim)) }
            if config.display.showSpeed { parts.append(Text("85.2 tok/s").font(pf).foregroundColor(dim)) }
            if config.display.showDuration { parts.append(Text("\u{23F1} 22m").font(pf).foregroundColor(dim)) }
            if config.display.showCost { parts.append(Text("Est. $12.97").font(pf).foregroundColor(dim)) }
            if !config.display.customLine.isEmpty {
                parts.append(Text(config.display.customLine).font(pf).foregroundColor(swiftUIColor(for: config.colors.custom)))
            }
            guard !parts.isEmpty else { return nil }
            return parts.enumerated().reduce(Text("")) { result, item in
                item.offset > 0 ? result + Text(" \u{2502} ").font(pf).foregroundColor(dim) + item.element : item.element
            }

        case "context":
            guard config.display.showContextBar else { return nil }
            let ctxColor = swiftUIColor(for: config.colors.context)
            let value: String
            switch config.display.contextValue {
            case "tokens": value = "28k/100k"
            case "remaining": value = "72k remaining"
            case "both": value = "28k/100k (28%)"
            default: value = "\u{2588}\u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}  28%"
            }
            return Text("Context ").font(pf).foregroundColor(dim) + Text(value).font(pf).foregroundColor(ctxColor)

        case "usage":
            guard config.display.showUsage else { return nil }
            let usageColor = swiftUIColor(for: config.colors.usage)
            let value = config.display.usageBarEnabled
                ? "\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}  18% (3h 39m / 5h)"
                : "18% (3h 39m / 5h)"
            return Text("Usage ").font(pf).foregroundColor(dim) + Text(value).font(pf).foregroundColor(usageColor)

        case "memory":
            guard config.display.showMemoryUsage else { return nil }
            return Text("Approx RAM ").font(pf).foregroundColor(dim)
                + Text("\u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}  5.8 GB / 16 GB (36%)").font(pf).foregroundColor(swiftUIColor(for: config.colors.usage))

        case "environment":
            guard config.display.showConfigCounts else { return nil }
            var result = Text("2 CLAUDE.md | 4 MCPs").font(pf).foregroundColor(dim)
            if config.display.showOutputStyle {
                result = result + Text(" | style: concise").font(pf).foregroundColor(dim)
            }
            return result

        case "tools":
            guard config.display.showTools else { return nil }
            return Text("\u{2713} ").font(pf).foregroundColor(.green)
                + Text("Edit \u{00D7}9 | ").font(pf).foregroundColor(dim)
                + Text("\u{2713} ").font(pf).foregroundColor(.green)
                + Text("Read \u{00D7}6 | ").font(pf).foregroundColor(dim)
                + Text("\u{2713} ").font(pf).foregroundColor(.green)
                + Text("Bash \u{00D7}4").font(pf).foregroundColor(dim)

        case "agents":
            guard config.display.showAgents else { return nil }
            return Text("\u{2713} ").font(pf).foregroundColor(.green)
                + Text("Explore").font(pf).foregroundColor(.purple)
                + Text(": Analyze codebase (1m 14s)").font(pf).foregroundColor(dim)

        case "todos":
            guard config.display.showTodos else { return nil }
            return Text("\u{2713} ").font(pf).foregroundColor(.green)
                + Text("All todos complete (8/8)").font(pf).foregroundColor(dim)

        default:
            return nil
        }
    }

    // MARK: - Layout Section

    private var layoutSection: some View {
        Section {
            Picker("Language", selection: $config.language) {
                Text("English").tag("en")
                Text("Chinese").tag("zh")
            }
            .onChange(of: config.language) { _, _ in saveConfig() }

            Picker("Line Layout", selection: $config.lineLayout) {
                Text("Expanded").tag("expanded")
                Text("Compact").tag("compact")
            }
            .onChange(of: config.lineLayout) { _, _ in saveConfig() }

            Toggle("Show Separators", isOn: $config.showSeparators)
                .onChange(of: config.showSeparators) { _, _ in saveConfig() }

            Picker("Path Levels", selection: $config.pathLevels) {
                Text("1").tag(1)
                Text("2").tag(2)
                Text("3").tag(3)
            }
            .onChange(of: config.pathLevels) { _, _ in saveConfig() }
        } header: {
            Text("Layout")
        } footer: {
            Text("Controls line density and project path display depth.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Display Section

    /// Maps an ANSI color name to a SwiftUI Color for the preview text.
    private func swiftUIColor(for name: String) -> Color {
        switch name {
        case "red": return .red
        case "green": return .green
        case "yellow": return .yellow
        case "magenta": return .purple
        case "cyan": return .cyan
        case "brightBlue": return Color(red: 0.4, green: 0.5, blue: 1.0)
        case "brightMagenta": return Color(red: 1.0, green: 0.4, blue: 1.0)
        case "dim": return .secondary
        default:
            // Hex color or custom color hex
            if name.hasPrefix("#") { return Color(hex: name) }
            if let idx = Int(name), idx >= 0, idx <= 255 { return .orange }
            return .secondary
        }
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>, preview: String, color: Color = .secondary, colorBinding: Binding<String>? = nil, onChange: @escaping () -> Void = {}) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                Spacer()
                if let binding = colorBinding {
                    inlineColorPicker(selection: binding)
                }
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .onChange(of: isOn.wrappedValue) { _, _ in onChange() }
            }
            Text(preview)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(colorBinding != nil ? swiftUIColor(for: colorBinding!.wrappedValue) : color)
        }
    }

    /// Compact inline color picker for toggle rows
    private func inlineColorPicker(selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(Self.colorOptions, id: \.self) { c in
                Text(c).tag(c)
            }
            if !config.customColors.isEmpty {
                Divider()
                ForEach(config.customColors.sorted(by: { $0.key < $1.key }), id: \.value) { name, hex in
                    Text(name).tag(hex)
                }
            }
        }
        .frame(width: 130)
        .onChange(of: selection.wrappedValue) { _, _ in saveConfig() }
    }

    private var displaySection: some View {
        Section {
            toggleRow("Show Model Name", isOn: $config.display.showModel,
                      preview: "[Opus 4.6 | Max]", color: .cyan,
                      colorBinding: $config.colors.model) { saveConfig() }

            if config.display.showModel {
                Picker("Model Format", selection: $config.display.modelFormat) {
                    Text("Full").tag("full")
                    Text("Compact").tag("compact")
                    Text("Short").tag("short")
                }
                .onChange(of: config.display.modelFormat) { _, _ in saveConfig() }

                TextField("Model Override", text: $config.display.modelOverride, prompt: Text("Leave empty for auto"))
                    .onChange(of: config.display.modelOverride) { _, _ in saveConfig() }
            }

            toggleRow("Show Project Path", isOn: $config.display.showProject,
                      preview: "my-project git:(main*)", color: .yellow,
                      colorBinding: $config.colors.project) { saveConfig() }

            toggleRow("Show Context Bar", isOn: $config.display.showContextBar,
                      preview: "Context \u{2588}\u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591} 45%", color: .green,
                      colorBinding: $config.colors.context) { syncElementOrder() }

            if config.display.showContextBar {
                Picker("Context Value", selection: $config.display.contextValue) {
                    Text("Percent").tag("percent")
                    Text("Tokens").tag("tokens")
                    Text("Remaining").tag("remaining")
                    Text("Both").tag("both")
                }
                .onChange(of: config.display.contextValue) { _, _ in saveConfig() }

                toggleRow("Token Breakdown at 85%+", isOn: $config.display.showTokenBreakdown,
                          preview: "(in: 45k, cache: 12k)", color: .secondary) { saveConfig() }
            }

            toggleRow("Show Config Counts", isOn: $config.display.showConfigCounts,
                      preview: "2 CLAUDE.md | 4 MCPs", color: .secondary,
                      colorBinding: $config.colors.label) { syncElementOrder() }

            toggleRow("Show Cost", isOn: $config.display.showCost,
                      preview: "Est. $12.97", colorBinding: $config.colors.label) { saveConfig() }

            toggleRow("Show Session Duration", isOn: $config.display.showDuration,
                      preview: "\u{23F1} 22m", colorBinding: $config.colors.label) { saveConfig() }

            toggleRow("Show Output Speed", isOn: $config.display.showSpeed,
                      preview: "out: 85.2 tok/s", colorBinding: $config.colors.label) { saveConfig() }

            toggleRow("Show Session Name", isOn: $config.display.showSessionName,
                      preview: "precious-sauteeing-hollerith", colorBinding: $config.colors.label) { saveConfig() }

            toggleRow("Show Claude Code Version", isOn: $config.display.showClaudeCodeVersion,
                      preview: "CC v2.1.92", colorBinding: $config.colors.label) { saveConfig() }

            toggleRow("Show Memory Usage", isOn: $config.display.showMemoryUsage,
                      preview: "Approx RAM \u{2588}\u{2588}\u{2591}\u{2591}\u{2591} 5.8 GB / 16 GB", colorBinding: $config.colors.label) { saveConfig() }

            toggleRow("Show Session Tokens", isOn: $config.display.showSessionTokens,
                      preview: "Tokens 125k (in: 45k, out: 80k, cache: 12k)", colorBinding: $config.colors.label) { saveConfig() }

            toggleRow("Show Output Style", isOn: $config.display.showOutputStyle,
                      preview: "style: concise", colorBinding: $config.colors.label) { saveConfig() }

            Picker("Auto-Compact Buffer", selection: $config.display.autocompactBuffer) {
                Text("Enabled").tag("enabled")
                Text("Disabled").tag("disabled")
            }
            .onChange(of: config.display.autocompactBuffer) { _, _ in saveConfig() }

            toggleRow("Custom Line", isOn: .constant(true),
                      preview: config.display.customLine.isEmpty ? "Optional custom status text" : config.display.customLine,
                      color: .secondary, colorBinding: $config.colors.custom) { }

            TextField("Custom Line Text", text: $config.display.customLine, prompt: Text("Optional custom status text"))
                .onChange(of: config.display.customLine) { _, _ in saveConfig() }
        } header: {
            Text("Display")
        } footer: {
            Text("Controls which information appears on the status line.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        Section {
            toggleRow("Show Usage Rate Limits", isOn: $config.display.showUsage,
                      preview: "Usage \u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591} 24% (resets in 4h)", color: Color(red: 0.4, green: 0.5, blue: 1.0),
                      colorBinding: $config.colors.usage) { syncElementOrder() }

            if config.display.showUsage {
                Toggle("Visual Bar", isOn: $config.display.usageBarEnabled)
                    .onChange(of: config.display.usageBarEnabled) { _, _ in saveConfig() }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("5-Hour Threshold")
                        Spacer()
                        Text("\(config.display.usageThreshold)%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.display.usageThreshold) },
                            set: { config.display.usageThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .onChange(of: config.display.usageThreshold) { _, _ in saveConfig() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("7-Day Threshold")
                        Spacer()
                        Text("\(config.display.sevenDayThreshold)%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.display.sevenDayThreshold) },
                            set: { config.display.sevenDayThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .onChange(of: config.display.sevenDayThreshold) { _, _ in saveConfig() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Environment Threshold")
                        Spacer()
                        Text("\(config.display.environmentThreshold)%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.display.environmentThreshold) },
                            set: { config.display.environmentThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .onChange(of: config.display.environmentThreshold) { _, _ in saveConfig() }
                }
            }
        } header: {
            Text("Usage")
        } footer: {
            Text("Rate limit display and warning thresholds.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Activity Lines Section

    private var activitySection: some View {
        Section {
            toggleRow("Show Tool Activity", isOn: $config.display.showTools,
                      preview: "\u{2713} Edit \u{00D7}9 | \u{2713} Read \u{00D7}6 | \u{2713} Bash \u{00D7}4",
                      colorBinding: $config.colors.label) { syncElementOrder() }

            toggleRow("Show Agent Status", isOn: $config.display.showAgents,
                      preview: "\u{2713} Explore: Analyze codebase (1m 14s)",
                      colorBinding: $config.colors.label) { syncElementOrder() }

            toggleRow("Show Todo Progress", isOn: $config.display.showTodos,
                      preview: "\u{2713} All todos complete (8/8)",
                      colorBinding: $config.colors.label) { syncElementOrder() }
        } header: {
            Text("Activity Lines")
        } footer: {
            Text("Real-time tool, agent, and task progress indicators.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Git Status Section

    private var gitStatusSection: some View {
        Section {
            toggleRow("Show Git Branch", isOn: $config.gitStatus.enabled,
                      preview: "git:(main)", color: .purple,
                      colorBinding: $config.colors.git) { saveConfig() }

            if config.gitStatus.enabled {
                toggleRow("Show Dirty Indicator", isOn: $config.gitStatus.showDirty,
                          preview: "git:(main*)", color: .purple,
                          colorBinding: $config.colors.gitBranch) { saveConfig() }

                toggleRow("Show Ahead/Behind", isOn: $config.gitStatus.showAheadBehind,
                          preview: "\u{2191}2 \u{2193}1", color: .cyan) { saveConfig() }

                toggleRow("Show File Stats", isOn: $config.gitStatus.showFileStats,
                          preview: "[+5 -2]  ~auth.ts  +config.json", color: .yellow) { saveConfig() }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Push Warning Threshold")
                        Spacer()
                        Text("\(config.gitStatus.pushWarningThreshold)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.gitStatus.pushWarningThreshold) },
                            set: { config.gitStatus.pushWarningThreshold = Int($0) }
                        ),
                        in: 0...50,
                        step: 1
                    )
                    .onChange(of: config.gitStatus.pushWarningThreshold) { _, _ in saveConfig() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Push Critical Threshold")
                        Spacer()
                        Text("\(config.gitStatus.pushCriticalThreshold)")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.gitStatus.pushCriticalThreshold) },
                            set: { config.gitStatus.pushCriticalThreshold = Int($0) }
                        ),
                        in: 0...50,
                        step: 1
                    )
                    .onChange(of: config.gitStatus.pushCriticalThreshold) { _, _ in saveConfig() }
                }
            }
        } header: {
            Text("Git Status")
        } footer: {
            Text("Git branch, dirty state, file changes, and push count warnings.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Colors Section

    private static let colorOptions = [
        "dim", "red", "green", "yellow", "magenta", "cyan", "brightBlue", "brightMagenta",
    ]

    private var colorsSection: some View {
        Section {
            colorPicker("Warning", selection: $config.colors.warning)
            colorPicker("Usage Warning", selection: $config.colors.usageWarning)
            colorPicker("Critical", selection: $config.colors.critical)
        } header: {
            Text("Theme Colors")
        } footer: {
            Text("Colors for warning states and thresholds. Element colors are set inline on each toggle above.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Custom Colors Section

    private var customColorsSection: some View {
        Section {
            ForEach(config.customColors.sorted(by: { $0.key < $1.key }), id: \.key) { name, hex in
                HStack {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 14, height: 14)
                    Text(name)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Text(hex)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    Button {
                        config.customColors.removeValue(forKey: name)
                        saveConfig()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if showingAddColor {
                HStack(spacing: 10) {
                    ColorPicker("", selection: $newColorPick, supportsOpacity: false)
                        .labelsHidden()
                    Text(newColorPick.toHex())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 65)
                    TextField("Color name", text: $newColorName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                    Spacer()
                    Button("Save") {
                        let name = newColorName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        config.customColors[name] = newColorPick.toHex()
                        saveConfig()
                        newColorName = ""
                        newColorPick = .orange
                        showingAddColor = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newColorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancel") {
                        showingAddColor = false
                        newColorName = ""
                    }
                    .controlSize(.small)
                }
            } else {
                Button {
                    showingAddColor = true
                } label: {
                    Label("Add Color", systemImage: "plus.circle")
                }
            }
        } header: {
            Text("My Colors")
        } footer: {
            Text("Create named colors with a visual picker. Use them in any color option above.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// All color options: ANSI presets + user's custom colors
    private var allColorOptions: [String] {
        var options = Self.colorOptions
        options.append(contentsOf: config.customColors.keys.sorted())
        return options
    }

    /// Reverse-lookup: find custom color name for a hex value stored in config.
    private func customColorName(for value: String) -> String? {
        config.customColors.first(where: { $0.value == value })?.key
    }

    /// Whether a value is a preset name OR a hex that matches a custom color.
    private func isPickerValue(_ value: String) -> Bool {
        Self.colorOptions.contains(value) || config.customColors.values.contains(value)
    }

    private func colorPicker(_ label: String, selection: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()

            if isPickerValue(selection.wrappedValue) {
                // Show swatch for custom color hex values
                if config.customColors.values.contains(selection.wrappedValue) {
                    Circle()
                        .fill(Color(hex: selection.wrappedValue))
                        .frame(width: 10, height: 10)
                }
                Picker("", selection: selection) {
                    ForEach(Self.colorOptions, id: \.self) { color in
                        Text(color).tag(color)
                    }
                    if !config.customColors.isEmpty {
                        Divider()
                        // Tag with HEX value so the plugin gets a valid color
                        ForEach(config.customColors.sorted(by: { $0.key < $1.key }), id: \.value) { name, hex in
                            Text(name).tag(hex)
                        }
                    }
                    Divider()
                    Text("Custom value...").tag("__raw__")
                }
                .frame(width: 160)
                .onChange(of: selection.wrappedValue) { _, newValue in
                    if newValue != "__raw__" { saveConfig() }
                }
            } else {
                // Raw value mode (hex, 256-color index, or unknown)
                TextField("#rrggbb or 0-255", text: selection)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 100)
                    .onSubmit { saveConfig() }
                Button {
                    selection.wrappedValue = "green"
                    saveConfig()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Back to preset picker")
            }
        }
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        Section {
            HStack(spacing: 12) {
                presetButton("Full", icon: "square.grid.3x3.fill") {
                    applyFullPreset()
                }
                presetButton("Essential", icon: "star.fill") {
                    applyEssentialPreset()
                }
                presetButton("Minimal", icon: "minus.circle") {
                    applyMinimalPreset()
                }
            }
        } header: {
            Text("Presets")
        } footer: {
            Text("Quick-apply a preset configuration. Full enables everything, Essential shows activity + git + duration, Minimal shows only core defaults.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func presetButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Element Order Helpers

    private func buildElementItems() {
        let knownKeys = HUDConfig.allElementKeys
        var items: [ElementItem] = []
        var seen = Set<String>()

        for key in config.elementOrder where knownKeys.contains(key) && !seen.contains(key) {
            items.append(ElementItem(id: key, isEnabled: isElementVisible(key)))
            seen.insert(key)
        }

        for key in knownKeys where !seen.contains(key) {
            items.append(ElementItem(id: key, isEnabled: isElementVisible(key)))
            seen.insert(key)
        }

        allElements = items
    }

    private func syncElementOrder() {
        config.elementOrder = allElements.filter { isElementVisible($0.id) }.map(\.id)
        saveConfig()
    }

    private func isElementVisible(_ id: String) -> Bool {
        switch id {
        case "project": return config.display.showProject
        case "context": return config.display.showContextBar
        case "usage": return config.display.showUsage
        case "memory": return config.display.showMemoryUsage
        case "environment": return config.display.showConfigCounts
        case "tools": return config.display.showTools
        case "agents": return config.display.showAgents
        case "todos": return config.display.showTodos
        default: return false
        }
    }

    private var visibleElements: [ElementItem] {
        allElements.filter { isElementVisible($0.id) }
    }

    private func buildGitSuffix() -> String {
        var gitSuffix = ""
        if config.gitStatus.enabled {
            var insideParens = "main"
            if config.gitStatus.showDirty { insideParens += "*" }
            if config.gitStatus.showFileStats { insideParens += " ?1" }
            gitSuffix = " git:(\(insideParens))"
            if config.gitStatus.showAheadBehind {
                gitSuffix += " \u{2191}2 \u{2193}1"
            }
        }
        return gitSuffix
    }

    // MARK: - Preview Builder

    private func buildPreview() -> String {
        let isExpanded = config.lineLayout == "expanded"
        var lines: [String] = []

        // --- Build git suffix ---
        var gitSuffix = ""
        if config.gitStatus.enabled {
            var insideParens = "main"
            if config.gitStatus.showDirty { insideParens += "*" }
            if config.gitStatus.showFileStats { insideParens += " ?1" }
            gitSuffix = " git:(\(insideParens))"
            if config.gitStatus.showAheadBehind {
                gitSuffix += " \u{2191}2 \u{2193}1"
            }
        }

        if isExpanded {
            let order = config.elementOrder.isEmpty ? HUDConfig.allElementKeys : config.elementOrder
            let activityKeys: Set<String> = ["tools", "agents", "todos"]
            var headerLines: [String] = []
            var activityLines: [String] = []
            var usedElements = Set<String>()

            for (i, element) in order.enumerated() {
                guard !usedElements.contains(element) else { continue }
                usedElements.insert(element)

                let next = i + 1 < order.count ? order[i + 1] : nil
                let companion = element == "context" ? "usage" : (element == "usage" ? "context" : nil)
                let isAdjacent = companion != nil && next == companion && !usedElements.contains(companion!)

                if isAdjacent, let comp = companion {
                    usedElements.insert(comp)
                    let first = element == "context" ? contextPreviewString() : usagePreviewString()
                    let second = element == "context" ? usagePreviewString() : contextPreviewString()
                    var parts: [String] = []
                    if let f = first { parts.append(f) }
                    if let s = second { parts.append(s) }
                    if !parts.isEmpty {
                        headerLines.append(parts.joined(separator: " \u{2502} "))
                    }
                    continue
                }

                if let line = previewLine(for: element, gitSuffix: gitSuffix) {
                    if activityKeys.contains(element) {
                        activityLines.append(line)
                    } else {
                        headerLines.append(line)
                    }
                }
            }

            lines.append(contentsOf: headerLines)

            if config.showSeparators && !activityLines.isEmpty && !headerLines.isEmpty {
                lines.append(String(repeating: "\u{2500}", count: 35))
            }

            lines.append(contentsOf: activityLines)

            // Session tokens (rendered after all elements, like the plugin does)
            if config.display.showSessionTokens {
                lines.append("Tokens 125k (in: 45k, out: 80k, cache: 12k)")
            }
        } else {
            // Compact: single line with all header info
            var parts: [String] = []
            let sep = config.showSeparators ? " | " : "  "

            if config.display.showModel {
                parts.append("[Opus 4.6 | Max]")
            }

            if config.display.showContextBar {
                switch config.display.contextValue {
                case "tokens": parts.append("28k/100k")
                case "remaining": parts.append("72k remaining")
                case "both": parts.append("28k/100k (28%)")
                default: parts.append("\u{2588}\u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591} 28%")
                }
            }

            if config.display.showUsage {
                if config.display.usageBarEnabled {
                    parts.append("Usage \u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591} 18%")
                } else {
                    parts.append("Usage 18%")
                }
            }

            parts.append("my-project\(gitSuffix)")

            if config.display.showSessionName {
                parts.append("precious-hollerith")
            }
            if config.display.showClaudeCodeVersion {
                parts.append("CC v2.1.92")
            }
            if config.display.showConfigCounts {
                parts.append("2 CLAUDE.md | 4 MCPs")
            }
            if config.display.showSpeed { parts.append("85.2 tok/s") }
            if config.display.showDuration { parts.append("\u{23F1} 22m") }
            if config.display.showCost { parts.append("Est. $12.97") }

            if !parts.isEmpty {
                lines.append(parts.joined(separator: sep))
            }

            // Separator between header and activity
            let hasActivity = config.display.showTools || config.display.showAgents || config.display.showTodos
            if config.showSeparators && hasActivity {
                lines.append(String(repeating: "\u{2500}", count: 35))
            }

            // Activity lines (always separate lines in both modes)
            if config.display.showTools {
                lines.append("\u{25D0} Edit: auth.ts | \u{2713} Bash \u{00D7}10 | \u{2713} Read \u{00D7}3 | \u{2713} Write \u{00D7}2")
            }

            if config.display.showAgents {
                lines.append("\u{2713} Explore: Explore codebase patterns (1m 14s)")
            }

            if config.display.showTodos {
                lines.append("\u{25B8}\u{25B8} accept edits on (shift+tab to cycle)")
            }
        }

        if lines.isEmpty {
            return "(nothing to display)"
        }

        return lines.joined(separator: "\n")
    }

    private func contextPreviewString() -> String? {
        guard config.display.showContextBar else { return nil }
        switch config.display.contextValue {
        case "tokens": return "Context 28k/100k"
        case "remaining": return "Context 72k remaining"
        case "both": return "Context 28k/100k (28%)"
        default: return "Context \u{2588}\u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}  28%"
        }
    }

    private func usagePreviewString() -> String? {
        guard config.display.showUsage else { return nil }
        if config.display.usageBarEnabled {
            return "Usage \u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}  18% (3h 39m / 5h)"
        } else {
            return "Usage 18% (3h 39m / 5h)"
        }
    }

    private func previewLine(for element: String, gitSuffix: String) -> String? {
        switch element {
        case "project":
            guard config.display.showModel || config.display.showProject else { return nil }
            var parts: [String] = []
            if config.display.showModel {
                let modelName: String
                switch config.display.modelFormat {
                case "short": modelName = "Opus 4.6"
                case "compact": modelName = "Opus 4.6"
                default: modelName = "Opus 4.6 (1M context)"
                }
                if !config.display.modelOverride.isEmpty {
                    parts.append("[\(config.display.modelOverride)]")
                } else {
                    parts.append("[\(modelName) | Max]")
                }
            }
            if config.display.showProject {
                parts.append("my-project\(gitSuffix)")
            }
            if config.display.showSessionName {
                parts.append("precious-hollerith")
            }
            if config.display.showClaudeCodeVersion {
                parts.append("CC v2.1.92")
            }
            if config.display.showSpeed {
                parts.append("85.2 tok/s")
            }
            if config.display.showDuration {
                parts.append("\u{23F1} 22m")
            }
            if config.display.showCost {
                parts.append("Est. $12.97")
            }
            if !config.display.customLine.isEmpty {
                parts.append(config.display.customLine)
            }
            return parts.isEmpty ? nil : parts.joined(separator: " \u{2502} ")

        case "context":
            return contextPreviewString()

        case "usage":
            return usagePreviewString()

        case "memory":
            guard config.display.showMemoryUsage else { return nil }
            return "Approx RAM \u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}  5.8 GB / 16 GB (36%)"

        case "environment":
            guard config.display.showConfigCounts else { return nil }
            var envParts = ["2 CLAUDE.md", "4 MCPs"]
            if config.display.showOutputStyle {
                envParts.append("style: concise")
            }
            return envParts.joined(separator: " | ")

        case "tools":
            guard config.display.showTools else { return nil }
            return "\u{25D0} Edit: auth.ts | \u{2713} Bash \u{00D7}10 | \u{2713} Read \u{00D7}3 | \u{2713} Write \u{00D7}2"

        case "agents":
            guard config.display.showAgents else { return nil }
            return "\u{2713} Explore: Explore codebase patterns (1m 14s)"

        case "todos":
            guard config.display.showTodos else { return nil }
            return "\u{25B8}\u{25B8} accept edits on (shift+tab to cycle)"

        default:
            return nil
        }
    }

    // MARK: - Presets

    private func applyFullPreset() {
        var d = HUDConfig.HUDDisplayConfig()
        d.showModel = true
        d.showProject = true
        d.showContextBar = true
        d.contextValue = "percent"
        d.showTokenBreakdown = true
        d.showConfigCounts = true
        d.showCost = true
        d.showDuration = true
        d.showSpeed = true
        d.showUsage = true
        d.usageBarEnabled = true
        d.showTools = true
        d.showAgents = true
        d.showTodos = true
        d.showSessionName = true
        d.showClaudeCodeVersion = true
        d.showMemoryUsage = true
        d.showSessionTokens = true
        d.showOutputStyle = true
        d.autocompactBuffer = "enabled"
        config.display = d
        config.lineLayout = "expanded"
        config.showSeparators = true
        config.pathLevels = 2
        config.elementOrder = HUDConfig.allElementKeys
        config.gitStatus = HUDConfig.HUDGitConfig(
            enabled: true, showDirty: true, showAheadBehind: true, showFileStats: true,
            pushWarningThreshold: 0, pushCriticalThreshold: 0
        )
        saveConfig()
        buildElementItems()
    }

    private func applyEssentialPreset() {
        var d = HUDConfig.HUDDisplayConfig()
        d.showModel = true
        d.showProject = true
        d.showContextBar = true
        d.showTokenBreakdown = true
        d.showDuration = true
        d.showTools = true
        d.showAgents = true
        d.showTodos = true
        config.display = d
        config.lineLayout = "expanded"
        config.showSeparators = true
        config.pathLevels = 2
        config.elementOrder = ["project", "context", "tools", "agents", "todos"]
        config.gitStatus = HUDConfig.HUDGitConfig(
            enabled: true, showDirty: true, showAheadBehind: false, showFileStats: false,
            pushWarningThreshold: 0, pushCriticalThreshold: 0
        )
        saveConfig()
        buildElementItems()
    }

    private func applyMinimalPreset() {
        config = HUDConfig()
        saveConfig()
        buildElementItems()
    }

    // MARK: - Credit Section

    private var creditSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "person.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Created by Jarrod Watts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Link("github.com/jarrodwatts/claude-hud",
                         destination: URL(string: "https://github.com/jarrodwatts/claude-hud")!)
                        .font(.caption)
                }
                Spacer()
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Config I/O

    private func checkInstallation() {
        let pluginsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/plugins/installed_plugins.json")
        guard let data = try? Data(contentsOf: pluginsURL),
              let installed = try? JSONDecoder().decode(InstalledPlugins.self, from: data),
              let entries = installed.plugins?["claude-hud@claude-hud"],
              let first = entries.first else {
            isInstalled = false
            installedVersion = nil
            return
        }
        isInstalled = true
        installedVersion = first.version
    }

    private func loadConfig() {
        let decoder = JSONDecoder()
        guard let data = try? Data(contentsOf: configURL),
              let loaded = try? decoder.decode(HUDConfig.self, from: data) else {
            // Try partial decode — merge whatever exists with defaults
            loadPartialConfig()
            hasLoadedOnce = true
            return
        }
        config = loaded
        hasLoadedOnce = true
    }

    /// Handles partial JSON that may only contain some keys (e.g. {"display":{"showTools":true}})
    private func loadPartialConfig() {
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Merge language
        if let v = json["language"] as? String { config.language = v }

        // Merge display (plugin stores usage fields here too)
        if let display = json["display"] as? [String: Any] {
            if let v = display["showModel"] as? Bool { config.display.showModel = v }
            if let v = display["showProject"] as? Bool { config.display.showProject = v }
            if let v = display["showContextBar"] as? Bool { config.display.showContextBar = v }
            if let v = display["contextValue"] as? String { config.display.contextValue = v }
            if let v = display["showTokenBreakdown"] as? Bool { config.display.showTokenBreakdown = v }
            if let v = display["showConfigCounts"] as? Bool { config.display.showConfigCounts = v }
            if let v = display["showCost"] as? Bool { config.display.showCost = v }
            if let v = display["showDuration"] as? Bool { config.display.showDuration = v }
            if let v = display["showSpeed"] as? Bool { config.display.showSpeed = v }
            if let v = display["showUsage"] as? Bool { config.display.showUsage = v }
            if let v = display["usageBarEnabled"] as? Bool { config.display.usageBarEnabled = v }
            if let v = display["showTools"] as? Bool { config.display.showTools = v }
            if let v = display["showAgents"] as? Bool { config.display.showAgents = v }
            if let v = display["showTodos"] as? Bool { config.display.showTodos = v }
            if let v = display["showSessionName"] as? Bool { config.display.showSessionName = v }
            if let v = display["showClaudeCodeVersion"] as? Bool { config.display.showClaudeCodeVersion = v }
            if let v = display["showMemoryUsage"] as? Bool { config.display.showMemoryUsage = v }
            if let v = display["showSessionTokens"] as? Bool { config.display.showSessionTokens = v }
            if let v = display["showOutputStyle"] as? Bool { config.display.showOutputStyle = v }
            if let v = display["autocompactBuffer"] as? String { config.display.autocompactBuffer = v }
            if let v = display["usageThreshold"] as? Int { config.display.usageThreshold = v }
            if let v = display["sevenDayThreshold"] as? Int { config.display.sevenDayThreshold = v }
            if let v = display["environmentThreshold"] as? Int { config.display.environmentThreshold = v }
            if let v = display["modelFormat"] as? String { config.display.modelFormat = v }
            if let v = display["modelOverride"] as? String { config.display.modelOverride = v }
            if let v = display["customLine"] as? String { config.display.customLine = v }
        }

        // Merge layout (top-level fields)
        if let v = json["lineLayout"] as? String { config.lineLayout = v }
        if let v = json["showSeparators"] as? Bool { config.showSeparators = v }
        if let v = json["pathLevels"] as? Int { config.pathLevels = v }

        // Merge elementOrder
        if let v = json["elementOrder"] as? [String] {
            let known = Set(HUDConfig.allElementKeys)
            let filtered = v.filter { known.contains($0) }
            if !filtered.isEmpty {
                config.elementOrder = filtered
            }
        }

        // Legacy: migrate old nested "layout" key
        if let layout = json["layout"] as? [String: Any] {
            if json["lineLayout"] == nil, let v = layout["lineLayout"] as? String { config.lineLayout = v }
            if json["showSeparators"] == nil, let v = layout["showSeparators"] as? Bool { config.showSeparators = v }
            if json["pathLevels"] == nil, let v = layout["pathLevels"] as? Int { config.pathLevels = v }
        }

        // Legacy: migrate old separate "usage" section into display
        if let usage = json["usage"] as? [String: Any] {
            if let v = usage["showUsage"] as? Bool { config.display.showUsage = v }
            if let v = usage["usageBarEnabled"] as? Bool { config.display.usageBarEnabled = v }
            if let v = usage["usageThreshold"] as? Int { config.display.usageThreshold = v }
            if let v = usage["sevenDayThreshold"] as? Int { config.display.sevenDayThreshold = v }
            if let v = usage["environmentThreshold"] as? Int { config.display.environmentThreshold = v }
        }

        // Merge gitStatus
        if let git = json["gitStatus"] as? [String: Any] {
            if let v = git["enabled"] as? Bool { config.gitStatus.enabled = v }
            if let v = git["showDirty"] as? Bool { config.gitStatus.showDirty = v }
            if let v = git["showAheadBehind"] as? Bool { config.gitStatus.showAheadBehind = v }
            if let v = git["showFileStats"] as? Bool { config.gitStatus.showFileStats = v }
            if let v = git["pushWarningThreshold"] as? Int { config.gitStatus.pushWarningThreshold = v }
            if let v = git["pushCriticalThreshold"] as? Int { config.gitStatus.pushCriticalThreshold = v }
        }

        // Merge colors
        if let colors = json["colors"] as? [String: Any] {
            if let v = colors["context"] as? String { config.colors.context = v }
            if let v = colors["usage"] as? String { config.colors.usage = v }
            if let v = colors["warning"] as? String { config.colors.warning = v }
            if let v = colors["usageWarning"] as? String { config.colors.usageWarning = v }
            if let v = colors["critical"] as? String { config.colors.critical = v }
            if let v = colors["model"] as? String { config.colors.model = v }
            if let v = colors["project"] as? String { config.colors.project = v }
            if let v = colors["git"] as? String { config.colors.git = v }
            if let v = colors["gitBranch"] as? String { config.colors.gitBranch = v }
            if let v = colors["label"] as? String { config.colors.label = v }
            if let v = colors["custom"] as? String { config.colors.custom = v }
        }

        // Merge custom colors
        if let cc = json["customColors"] as? [String: String] {
            config.customColors = cc
        }
    }

    /// Top-level keys that HUDConfig models — used to merge without destroying unknown plugin keys.
    private static let knownHUDConfigKeys: Set<String> = [
        "language", "display", "lineLayout", "showSeparators", "pathLevels", "elementOrder", "gitStatus", "colors", "customColors",
    ]

    private func saveConfig() {
        guard hasLoadedOnce else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let encodedData = try? encoder.encode(config) else { return }

        // Ensure directory exists
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Load existing JSON to preserve unknown keys the plugin may use
        var existingJSON: [String: Any] = [:]
        if let fileData = try? Data(contentsOf: configURL),
           let json = try? JSONSerialization.jsonObject(with: fileData) as? [String: Any] {
            existingJSON = json
        }

        // Merge our known keys on top
        if let configJSON = try? JSONSerialization.jsonObject(with: encodedData) as? [String: Any] {
            for (key, value) in configJSON {
                existingJSON[key] = value
            }
            // Remove keys that our model explicitly set to nil (encoded as absent)
            for key in existingJSON.keys {
                if configJSON[key] == nil, Self.knownHUDConfigKeys.contains(key) {
                    existingJSON.removeValue(forKey: key)
                }
            }
        }

        // Strip empty strings from display that the plugin would misinterpret as overrides
        if var display = existingJSON["display"] as? [String: Any] {
            if display["modelOverride"] as? String == "" { display.removeValue(forKey: "modelOverride") }
            if display["customLine"] as? String == "" { display.removeValue(forKey: "customLine") }
            existingJSON["display"] = display
        }

        if let outputData = try? JSONSerialization.data(withJSONObject: existingJSON, options: [.prettyPrinted, .sortedKeys]) {
            try? outputData.write(to: configURL, options: .atomic)
        }
    }
}

// MARK: - Preview Drop Delegate

struct PreviewDropDelegate: DropDelegate {
    let item: ElementItem
    @Binding var allElements: [ElementItem]
    @Binding var draggedElementID: String?
    let onReorder: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggedElementID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID = draggedElementID,
              draggedID != item.id,
              let fromIndex = allElements.firstIndex(where: { $0.id == draggedID }),
              let toIndex = allElements.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            allElements.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
        onReorder()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedElementID != nil
    }
}

// MARK: - Color Hex Helpers

extension Color {
    /// Create a Color from a hex string like "#ff6600"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        if hex.count == 6 {
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        } else {
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }

    /// Convert a Color to "#rrggbb" hex string
    func toHex() -> String {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else {
            return "#000000"
        }
        let r = Int(round(components.redComponent * 255))
        let g = Int(round(components.greenComponent * 255))
        let b = Int(round(components.blueComponent * 255))
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
