import SwiftUI

struct HierarchicalModelPicker: View {
    @Binding var selectedModelId: String
    /// nil == no model override (empty selectedModelId). When nil, no family
    /// segment is highlighted, so an unset model never masquerades as a real pick.
    @State private var selectedFamily: ModelFamily?
    @State private var isCustomMode: Bool
    @State private var customModelId: String
    /// Value to restore if the user cancels out of custom entry.
    @State private var modelBeforeCustom: String = ""
    @FocusState private var customFieldFocused: Bool

    /// Sentinel selection tag for the "no override" state.
    private let unsetTag = ""
    /// Local-only tag for the "Custom..." row. It is never written to `selectedModelId`.
    private let customTag = "\u{0}custom"

    init(selectedModelId: Binding<String>) {
        _selectedModelId = selectedModelId
        let modelId = selectedModelId.wrappedValue
        let isCustom = HierarchicalModelPicker.isCustomValue(modelId)
        _isCustomMode = State(initialValue: isCustom)
        _customModelId = State(initialValue: isCustom ? modelId : "")
        // Empty model => no family highlighted; otherwise derive from the id.
        _selectedFamily = State(initialValue: modelId.isEmpty ? nil : family(for: modelId))
    }

    /// A non-empty id the catalog does not know is a custom id (checked against the catalog,
    /// never by substring, so "my-opus-proxy" stays custom while being typed).
    static func isCustomValue(_ modelId: String) -> Bool {
        !modelId.isEmpty && findModel(byModelId: modelId) == nil
    }

    private var pickerVersions: [ModelVersion] {
        guard let fam = selectedFamily else { return [] }
        return versions(for: fam)
    }

    /// Binding for the Version picker: shows the stored model, and routes "Custom..." into
    /// custom mode instead of writing a placeholder to settings.
    private var versionSelection: Binding<String> {
        Binding(
            get: { selectedModelId },
            set: { newValue in
                if newValue == customTag {
                    modelBeforeCustom = selectedModelId
                    customModelId = ""
                    isCustomMode = true
                    customFieldFocused = true
                } else {
                    selectedModelId = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Family (optional selection — nothing highlighted when unset)
            Picker("Family", selection: $selectedFamily) {
                ForEach(ModelFamily.allCases) { fam in
                    Label(fam.rawValue, systemImage: fam.icon)
                        .tag(Optional(fam))
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedFamily) { _, newFamily in
                // Only auto-switch when the user picked a different family. If the current
                // model already belongs to this family (e.g. an external `opus[1m]` edit
                // re-synced the segment), keep it — otherwise we'd overwrite the file.
                if !isCustomMode, let fam = newFamily, family(for: selectedModelId) != fam {
                    let newVersions = versions(for: fam)
                    if !newVersions.contains(where: { $0.modelId == selectedModelId }),
                       let latest = newVersions.first(where: { $0.isLatest }) {
                        selectedModelId = latest.modelId
                    }
                }
            }

            // Row 2: Version or Custom
            if isCustomMode {
                HStack {
                    TextField("Custom model ID", text: $customModelId)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($customFieldFocused)
                        .onSubmit { commitCustom() }
                        .onChange(of: customFieldFocused) { _, focused in
                            if !focused { commitCustom() }
                        }
                    Button("Cancel") {
                        isCustomMode = false
                        customModelId = ""
                        selectedModelId = modelBeforeCustom
                        syncFromModelId()
                    }
                }
            } else {
                Picker("Version", selection: versionSelection) {
                    Text("Default — Claude Code decides").tag(unsetTag)
                    ForEach(pickerVersions) { version in
                        Text(version.displayName).tag(version.modelId)
                    }
                    // A hidden/legacy stored model has no visible row; keep it selectable
                    // so the control shows its name instead of going blank.
                    if !selectedModelId.isEmpty,
                       !pickerVersions.contains(where: { $0.modelId == selectedModelId }),
                       findModel(byModelId: selectedModelId) != nil {
                        Text(displayName(for: selectedModelId)).tag(selectedModelId)
                    }
                    Divider()
                    Text("Custom...").tag(customTag)
                }
            }

            // Row 3: Description
            Text(descriptionText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            syncFromModelId()
        }
        .onChange(of: selectedModelId) { _, _ in
            syncFromModelId()
        }
    }

    private var descriptionText: String {
        if isCustomMode { return "Enter a custom model identifier, then press Return" }
        guard let fam = selectedFamily else {
            return "No model set — Claude Code uses its own default."
        }
        return fam.description
    }

    /// Writes the typed id once (submit / focus loss). An empty field writes nothing.
    private func commitCustom() {
        let trimmed = customModelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != selectedModelId else { return }
        selectedModelId = trimmed
    }

    private func syncFromModelId() {
        if selectedModelId.isEmpty {
            // Empty is also what an open, still-empty custom field looks like: leave it open.
            if !isCustomMode { selectedFamily = nil }
            return
        }
        if HierarchicalModelPicker.isCustomValue(selectedModelId) {
            isCustomMode = true
            customModelId = selectedModelId
            selectedFamily = family(for: selectedModelId)
        } else {
            isCustomMode = false
            if let fam = family(for: selectedModelId), selectedFamily != fam {
                selectedFamily = fam
            }
        }
    }
}
