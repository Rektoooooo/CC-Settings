import SwiftUI

/// Structured editor for a custom theme's `name`, `base` and `overrides`. A row shows the
/// base palette's colour until the user changes it; only changed colours are written to the
/// file's `overrides`. Keys this app does not model are kept verbatim and listed read-only.
struct ThemeColorsEditor: View {
    @Binding var theme: ThemeFile
    let onChange: () -> Void
    let onConvertLegacy: () -> Void

    /// Palette keys grouped for display. Anything not listed lands in "Other".
    private static let groups: [(title: String, keys: [String])] = [
        ("Text & Surfaces", ["text", "inverseText", "subtle", "inactive", "inactiveShimmer", "background",
                              "userMessageBackground", "userMessageBackgroundHover", "composerSidebarBackground",
                              "selectionBg", "bashMessageBackgroundColor", "memoryBackgroundColor"]),
        ("Brand", ["claude", "claudeShimmer", "claudeBlue_FOR_SYSTEM_SPINNER", "claudeBlueShimmer_FOR_SYSTEM_SPINNER",
                   "professionalBlue", "chromeYellow", "clawd_body", "clawd_background"]),
        ("Borders & Modes", ["promptBorder", "promptBorderShimmer", "bashBorder", "planMode", "autoAccept",
                             "autoAcceptShimmer", "permission", "permissionShimmer", "ide", "skill"]),
        ("Status", ["success", "error", "warning", "warningShimmer", "merged", "suggestion", "remember",
                    "fastMode", "fastModeShimmer", "effortUltra", "rate_limit_fill", "rate_limit_empty",
                    "briefLabelYou", "briefLabelClaude"]),
        ("Diff", ["diffAdded", "diffRemoved", "diffAddedDimmed", "diffRemovedDimmed", "diffAddedWord", "diffRemovedWord"]),
        ("Subagents", ["red_FOR_SUBAGENTS_ONLY", "blue_FOR_SUBAGENTS_ONLY", "green_FOR_SUBAGENTS_ONLY",
                       "yellow_FOR_SUBAGENTS_ONLY", "purple_FOR_SUBAGENTS_ONLY", "orange_FOR_SUBAGENTS_ONLY",
                       "pink_FOR_SUBAGENTS_ONLY", "cyan_FOR_SUBAGENTS_ONLY"]),
        ("Rainbow", ["rainbow_red", "rainbow_orange", "rainbow_yellow", "rainbow_green", "rainbow_blue",
                     "rainbow_indigo", "rainbow_violet", "rainbow_red_shimmer", "rainbow_orange_shimmer",
                     "rainbow_yellow_shimmer", "rainbow_green_shimmer", "rainbow_blue_shimmer",
                     "rainbow_indigo_shimmer", "rainbow_violet_shimmer"]),
    ]

    private var groupsWithOther: [(title: String, keys: [String])] {
        let listed = Set(Self.groups.flatMap { $0.keys })
        let other = ClaudeThemePalette.keys.filter { !listed.contains($0) }
        return other.isEmpty ? Self.groups : Self.groups + [("Other", other)]
    }

    var body: some View {
        Form {
            if theme.needsLegacyConversion {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Old flat format", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.subheadline.bold())
                        Text("This file uses colour keys Claude Code never read (\(theme.legacyFlatColors.count) found). Convert it to the real {name, base, overrides} format. Colours with a clear counterpart become overrides, the rest stay in the file, and the original is kept as \(theme.id).json.bak.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Convert to Claude Code format", action: onConvertLegacy)
                    }
                }
            }

            Section("Identity") {
                LabeledContent("Name") {
                    TextField(theme.id, text: Binding(
                        get: { theme.name },
                        set: { theme.name = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? theme.id : $0; onChange() }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                Picker("Base", selection: Binding(
                    get: { theme.base },
                    set: { theme.base = $0; onChange() }
                )) {
                    ForEach(ClaudeThemePalette.baseNames, id: \.self) { Text($0).tag($0) }
                }
                Text("Colours you don't override come from this built-in palette. Only keys that exist in the base are honoured.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(groupsWithOther, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.keys, id: \.self) { key in
                        colorRow(key)
                    }
                }
            }

            let extras = theme.extraOverrides.keys.sorted()
            if !extras.isEmpty || !theme.unknownFields.isEmpty || !theme.legacyFlatColors.isEmpty {
                Section {
                    DisclosureGroup("Preserved fields (\(extras.count + theme.unknownFields.count + theme.legacyFlatColors.count))") {
                        ForEach(extras, id: \.self) { key in
                            preservedRow("overrides.\(key)", theme.extraOverrides[key])
                        }
                        ForEach(theme.unknownFields.keys.sorted(), id: \.self) { key in
                            preservedRow(key, theme.unknownFields[key])
                        }
                        ForEach(theme.legacyFlatColors.keys.sorted(), id: \.self) { key in
                            preservedRow(key, theme.legacyFlatColors[key])
                        }
                        Text("Claude Code ignores these. They are kept through every save; edit in JSON view to change them.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Rows

    @ViewBuilder
    private func colorRow(_ key: String) -> some View {
        let isOverridden = theme.overrides[key] != nil
        LabeledContent {
            HStack(spacing: 8) {
                Text(theme.effectiveValue(for: key) ?? "—")
                    .font(.caption.monospaced())
                    .foregroundColor(isOverridden ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 110, alignment: .trailing)
                ColorPicker("", selection: colorBinding(for: key), supportsOpacity: false)
                    .labelsHidden()
                Button {
                    theme.overrides.removeValue(forKey: key)
                    onChange()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .help("Reset to the base palette's colour")
                .opacity(isOverridden ? 1 : 0)
                .disabled(!isOverridden)
            }
        } label: {
            Text(key)
                .font(.callout.monospaced())
                .fontWeight(isOverridden ? .semibold : .regular)
        }
    }

    private func preservedRow(_ key: String, _ value: Any?) -> some View {
        HStack {
            Text(key).font(.caption.monospaced())
            Spacer()
            Text(stringPreview(of: value))
                .font(.caption.monospaced())
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func colorBinding(for key: String) -> Binding<Color> {
        Binding<Color>(
            get: { ThemeColorValue.color(theme.effectiveValue(for: key)) ?? Color.gray.opacity(0.25) },
            set: { newColor in
                theme.overrides[key] = newColor.hexString ?? "#000000"
                onChange()
            }
        )
    }

    private func stringPreview(of value: Any?) -> String {
        switch value {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        case let arr as [Any]: return "[\(arr.count) items]"
        case let dict as [String: Any]: return "{\(dict.count) keys}"
        case nil: return "—"
        default: return String(describing: value ?? "—")
        }
    }
}
