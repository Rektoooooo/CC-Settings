import SwiftUI
import AppKit

enum ThemeEditorMode: String, CaseIterable {
    case structured = "Structured"
    case json = "JSON"
}

/// Selection model that distinguishes the two kinds of theme rows. Built-ins
/// can be activated but not edited; custom themes are files in
/// `~/.claude/themes/` and round-trip through the editor.
enum ThemeSelection: Hashable {
    case builtIn(String)
    case custom(String)
}

struct ThemesView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var themes: [ThemeFile] = []
    @State private var selection: ThemeSelection?
    @State private var searchText: String = ""
    @State private var editorMode: ThemeEditorMode = .structured
    @State private var rawJSONText: String = ""
    @State private var jsonError: String?
    @State private var isSyncingFromDisk = false
    @State private var showDeleteConfirm = false
    @State private var pendingDelete: ThemeFile?

    private var activeThemeName: String? {
        configManager.settings.theme
    }

    private var filteredBuiltIns: [BuiltInTheme] {
        guard !searchText.isEmpty else { return ThemePresets.builtIns }
        let q = searchText.lowercased()
        return ThemePresets.builtIns.filter {
            $0.id.lowercased().contains(q) ||
            $0.displayName.lowercased().contains(q)
        }
    }

    private var filteredCustomThemes: [ThemeFile] {
        guard !searchText.isEmpty else { return themes }
        let q = searchText.lowercased()
        return themes.filter {
            $0.id.lowercased().contains(q) ||
            ($0.colors.name?.lowercased().contains(q) ?? false) ||
            ($0.colors.description?.lowercased().contains(q) ?? false)
        }
    }

    private var selectedCustomTheme: ThemeFile? {
        if case .custom(let id) = selection {
            return themes.first(where: { $0.id == id })
        }
        return nil
    }

    private var selectedBuiltIn: BuiltInTheme? {
        if case .builtIn(let id) = selection {
            return ThemePresets.builtIns.first(where: { $0.id == id })
        }
        return nil
    }

    var body: some View {
        HSplitView {
            listPane
                .frame(minWidth: 240, idealWidth: 300, maxWidth: 380)

            if let theme = selectedCustomTheme {
                customDetailPane(for: theme)
            } else if let builtIn = selectedBuiltIn {
                builtInDetailPane(for: builtIn)
            } else {
                emptyDetailPane
            }
        }
        .onAppear { reload() }
        .onChange(of: configManager.settings) { _, _ in reload() }
        .confirmationDialog(
            "Delete this theme?",
            isPresented: $showDeleteConfirm,
            presenting: pendingDelete
        ) { theme in
            Button("Delete \(theme.id).json", role: .destructive) {
                deleteTheme(theme)
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - List pane

    @ViewBuilder
    private var listPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search themes", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List(selection: $selection) {
                Section("Built-in") {
                    ForEach(filteredBuiltIns) { theme in
                        builtInRow(theme)
                            .tag(ThemeSelection.builtIn(theme.id))
                            .contentShape(Rectangle())
                    }
                }

                if !filteredCustomThemes.isEmpty {
                    Section("Custom") {
                        ForEach(filteredCustomThemes) { theme in
                            ThemeListRow(theme: theme, isActive: theme.id == activeThemeName)
                                .tag(ThemeSelection.custom(theme.id))
                                .contentShape(Rectangle())
                        }
                    }
                } else if searchText.isEmpty {
                    Section("Custom") {
                        emptyCustomThemesRow
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 8) {
                Menu {
                    Button("Blank Theme") {
                        createNewTheme(from: nil)
                    }
                    Divider()
                    Section("From Preset") {
                        ForEach(ThemePresets.starters) { preset in
                            Button(preset.displayName) {
                                createNewTheme(from: preset)
                            }
                        }
                    }
                } label: {
                    Label("New", systemImage: "plus")
                }
                Button {
                    importTheme()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func builtInRow(_ theme: BuiltInTheme) -> some View {
        HStack(spacing: 10) {
            Image(systemName: theme.icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            Text(theme.displayName)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if isActive(builtIn: theme) {
                Text("Active")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    /// Auto is "active" when no theme is set; everything else matches the stored value.
    private func isActive(builtIn theme: BuiltInTheme) -> Bool {
        if theme.isAuto { return activeThemeName == nil }
        return theme.id == activeThemeName
    }

    private func activate(builtIn theme: BuiltInTheme) {
        configManager.saveField("theme", value: theme.isAuto ? nil : theme.id)
    }

    @ViewBuilder
    private var emptyCustomThemesRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No custom themes yet.")
                .font(.caption.weight(.medium))
            Text("Click + New → From Preset to scaffold one. Files land in ~/.claude/themes/.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty detail pane

    @ViewBuilder
    private var emptyDetailPane: some View {
        VStack(spacing: 14) {
            Image(systemName: "paintbrush")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("Select a Theme")
                .font(.title2.weight(.semibold))
                .foregroundColor(.secondary)
            VStack(spacing: 6) {
                Text("Built-in themes are baked into Claude Code itself —")
                Text("activate them or scaffold a custom theme from a preset.")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Built-in detail pane

    @ViewBuilder
    private func builtInDetailPane(for theme: BuiltInTheme) -> some View {
        let active = isActive(builtIn: theme)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Identity row
                HStack(spacing: 14) {
                    Image(systemName: theme.icon)
                        .font(.system(size: 36))
                        .foregroundColor(.accentColor)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(theme.displayName)
                            .font(.title2.weight(.semibold))
                        Text(theme.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                // Actions
                HStack(spacing: 10) {
                    if active {
                        // Auto can't be "deactivated" — it's the absence state. For others,
                        // Deactivate switches back to Auto by clearing settings.theme.
                        if !theme.isAuto {
                            Button {
                                configManager.saveField("theme", value: nil)
                            } label: {
                                Label("Switch to Auto", systemImage: "circle.lefthalf.filled")
                            }
                        } else {
                            Label("Currently Active", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    } else {
                        Button {
                            activate(builtIn: theme)
                        } label: {
                            Label("Set as Active", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    if !theme.isAuto {
                        Button {
                            duplicateBuiltIn(theme)
                        } label: {
                            Label("Duplicate as Editable", systemImage: "doc.on.doc")
                        }
                    }
                    Spacer(minLength: 0)
                }

                Divider()

                if theme.isAuto {
                    // No preview for Auto — there's no fixed palette to show.
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("Auto means no `theme` setting is written to ~/.claude/settings.json. Claude Code falls back to defaults that work with your terminal's colors.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "lock")
                            .foregroundColor(.secondary)
                        Text("Built into Claude Code — colors are baked into the CLI binary and can't be edited.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("Preview")
                                .font(.headline)
                            Text("(approximate)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        ThemePreview(theme: ThemeFile(
                            id: theme.id,
                            url: URL(fileURLWithPath: "/dev/null"),
                            colors: theme.approximateColors,
                            unknownFields: [:]
                        ))
                        .frame(height: 260)
                        Text("These colors are CC Settings' best-effort approximation. The CLI's actual built-in palette may differ.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(theme.id)
    }

    private func duplicateBuiltIn(_ theme: BuiltInTheme) {
        let url = configManager.themeURL(forNewName: "\(theme.id)-copy")
        let newID = url.deletingPathExtension().lastPathComponent
        var colors = theme.approximateColors
        colors.name = newID
        colors.description = "Editable copy of the built-in \(theme.displayName) theme (colors are approximate)."
        let dup = ThemeFile(id: newID, url: url, colors: colors, unknownFields: [:])
        do {
            try configManager.saveTheme(dup)
            reload()
            selection = .custom(newID)
            editorMode = .structured
        } catch {
            print("[Themes] duplicate built-in failed: \(error)")
        }
    }

    // MARK: - Custom theme detail pane

    @ViewBuilder
    private func customDetailPane(for theme: ThemeFile) -> some View {
        let bindingIndex = themes.firstIndex(of: theme) ?? 0
        let isActive = theme.id == activeThemeName

        VStack(spacing: 0) {
            // Header bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.colors.name ?? theme.id)
                        .font(.title3.weight(.semibold))
                    Text(theme.url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isActive {
                    Button {
                        configManager.saveField("theme", value: nil)
                    } label: {
                        Label("Deactivate", systemImage: "checkmark.circle.fill")
                    }
                } else {
                    Button {
                        configManager.saveField("theme", value: theme.id)
                    } label: {
                        Label("Set as Active", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button {
                    duplicateTheme(theme)
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) {
                    pendingDelete = theme
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
            .padding()

            Divider()

            // Mode picker
            Picker("Editor", selection: $editorMode) {
                ForEach(ThemeEditorMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            .padding(.horizontal)
            .padding(.top, 8)
            .onChange(of: editorMode) { _, newValue in
                if newValue == .json {
                    syncJSONText(from: theme)
                }
            }

            Divider()
                .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch editorMode {
                    case .structured:
                        ThemeColorsEditor(
                            theme: themesBinding(at: bindingIndex),
                            onChange: { persistTheme(at: bindingIndex) }
                        )
                        .frame(minHeight: 480)
                    case .json:
                        jsonEditor
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview")
                            .font(.headline)
                        ThemePreview(theme: theme)
                            .frame(height: 240)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .id(theme.id)   // reset scroll position when switching between custom themes
        }
    }

    // MARK: - JSON editor

    @ViewBuilder
    private var jsonEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Raw JSON")
                    .font(.headline)
                Spacer()
                if let err = jsonError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Label("Valid", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            TextEditor(text: $rawJSONText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 320)
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: rawJSONText) { _, newValue in
                    applyJSONEdit(newValue)
                }
        }
        .padding(.horizontal)
    }

    // MARK: - Reload & persistence

    private func reload() {
        isSyncingFromDisk = true
        let loaded = configManager.loadThemes()
        themes = loaded

        // Drop selection if the custom theme no longer exists. Built-in selection persists.
        if case .custom(let id) = selection, !loaded.contains(where: { $0.id == id }) {
            selection = nil
        }

        if editorMode == .json, let theme = selectedCustomTheme {
            syncJSONText(from: theme)
        }
        DispatchQueue.main.async { isSyncingFromDisk = false }
    }

    private func themesBinding(at index: Int) -> Binding<ThemeFile> {
        Binding<ThemeFile>(
            get: {
                guard themes.indices.contains(index) else {
                    return ThemeFile(id: "", url: URL(fileURLWithPath: "/"), colors: ThemeColors(), unknownFields: [:])
                }
                return themes[index]
            },
            set: { newValue in
                guard themes.indices.contains(index) else { return }
                themes[index] = newValue
            }
        )
    }

    private func persistTheme(at index: Int) {
        guard !isSyncingFromDisk, themes.indices.contains(index) else { return }
        do {
            try configManager.saveTheme(themes[index])
        } catch {
            print("[Themes] save failed: \(error.localizedDescription)")
        }
    }

    private func syncJSONText(from theme: ThemeFile) {
        if let data = try? theme.serialize(), let text = String(data: data, encoding: .utf8) {
            rawJSONText = text
            jsonError = nil
        } else {
            rawJSONText = ""
            jsonError = "couldn't serialize theme"
        }
    }

    private func applyJSONEdit(_ text: String) {
        guard !isSyncingFromDisk, let theme = selectedCustomTheme else { return }
        guard let data = text.data(using: .utf8) else { return }
        do {
            let obj = try JSONSerialization.jsonObject(with: data)
            guard let dict = obj as? [String: Any] else {
                jsonError = "top level must be a JSON object"
                return
            }
            jsonError = nil
            var newColors = ThemeColors()
            var unknown: [String: Any] = [:]
            for (key, value) in dict {
                if ThemeColors.knownKeys.contains(key), let s = value as? String {
                    newColors.setValue(s, forKey: key)
                } else {
                    unknown[key] = value
                }
            }
            var updated = theme
            updated.colors = newColors
            updated.unknownFields = unknown
            if let idx = themes.firstIndex(where: { $0.id == theme.id }) {
                themes[idx] = updated
                persistTheme(at: idx)
            }
        } catch {
            jsonError = error.localizedDescription
        }
    }

    // MARK: - Theme actions

    /// `preset == nil` scaffolds a minimal blank theme; otherwise uses the
    /// preset's colors as the starting point.
    private func createNewTheme(from preset: ThemePresets.Preset?) {
        let basename = preset?.suggestedFilename ?? "untitled"
        let url = configManager.themeURL(forNewName: basename)
        let id = url.deletingPathExtension().lastPathComponent

        var colors: ThemeColors
        if let preset = preset {
            colors = preset.colors
            // Preset templates ship with a fixed (dark) surface — swap it to a
            // light or dark surface to match the app's current appearance.
            if colorScheme == .light {
                colors.background = "#ffffff"
                colors.foreground = "#1f2328"
            } else {
                colors.background = "#1e1e1e"
                colors.foreground = "#f8f8f2"
            }
        } else {
            colors = ThemeColors.starter
        }
        colors.name = id

        let theme = ThemeFile(id: id, url: url, colors: colors, unknownFields: [:])
        do {
            try configManager.saveTheme(theme)
            reload()
            selection = .custom(id)
            editorMode = .structured
        } catch {
            print("[Themes] new theme failed: \(error)")
        }
    }

    private func duplicateTheme(_ theme: ThemeFile) {
        let url = configManager.themeURL(forNewName: "\(theme.id)-copy")
        let newID = url.deletingPathExtension().lastPathComponent
        var copy = theme.colors
        copy.name = newID
        let dup = ThemeFile(id: newID, url: url, colors: copy, unknownFields: theme.unknownFields)
        do {
            try configManager.saveTheme(dup)
            reload()
            selection = .custom(newID)
        } catch {
            print("[Themes] duplicate failed: \(error)")
        }
    }

    private func deleteTheme(_ theme: ThemeFile) {
        let wasActive = theme.id == activeThemeName
        let didDelete = configManager.deleteTheme(at: theme.url)
        if didDelete && wasActive {
            configManager.saveField("theme", value: nil)
        }
        pendingDelete = nil
        reload()
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.json]
        panel.message = "Choose a .json theme file to import into ~/.claude/themes/"

        guard panel.runModal() == .OK, let source = panel.url else { return }
        guard source.pathExtension.lowercased() == "json" else { return }

        let baseName = source.deletingPathExtension().lastPathComponent
        let dest = configManager.themeURL(forNewName: baseName)
        do {
            try FileManager.default.copyItem(at: source, to: dest)
            reload()
            selection = .custom(dest.deletingPathExtension().lastPathComponent)
        } catch {
            print("[Themes] import failed: \(error)")
        }
    }
}
