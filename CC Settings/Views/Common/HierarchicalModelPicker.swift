import SwiftUI

struct HierarchicalModelPicker: View {
    @Binding var selectedModelId: String
    @State private var selectedFamily: ModelFamily
    @State private var isCustomMode: Bool
    @State private var customModelId: String

    init(selectedModelId: Binding<String>) {
        _selectedModelId = selectedModelId
        let modelId = selectedModelId.wrappedValue
        let initialFamily = family(for: modelId) ?? .sonnet
        _selectedFamily = State(initialValue: initialFamily)
        let knownModel = findModel(byModelId: modelId) != nil
        let isCustom = !knownModel && !modelId.isEmpty && modelId != "__custom__"
        _isCustomMode = State(initialValue: isCustom)
        _customModelId = State(initialValue: isCustom ? modelId : "")
    }

    /// Versions to show in the dropdown — derived from selectedModelId when it
    /// doesn't match selectedFamily, preventing the "invalid selection" warning
    /// that occurs when @State is stale after a SwiftUI view identity reuse.
    private var pickerVersions: [ModelVersion] {
        let familyVersions = versions(for: selectedFamily)
        if familyVersions.contains(where: { $0.modelId == selectedModelId })
            || selectedModelId == "__custom__" {
            return familyVersions
        }
        if let derivedFamily = family(for: selectedModelId) {
            return versions(for: derivedFamily)
        }
        return familyVersions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Family
            Picker("Family", selection: $selectedFamily) {
                ForEach(ModelFamily.allCases) { fam in
                    Label(fam.rawValue, systemImage: fam.icon)
                        .tag(fam)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedFamily) { _, newFamily in
                if !isCustomMode {
                    let newVersions = versions(for: newFamily)
                    // Only auto-switch if the current selection isn't already in this family
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
                        .onSubmit {
                            selectedModelId = customModelId
                        }
                        .onChange(of: customModelId) { _, newValue in
                            selectedModelId = newValue
                        }
                    Button("Cancel") {
                        isCustomMode = false
                        if let latest = versions(for: selectedFamily).first(where: { $0.isLatest }) {
                            selectedModelId = latest.modelId
                        }
                    }
                }
            } else {
                Picker("Version", selection: $selectedModelId) {
                    ForEach(pickerVersions) { version in
                        Text(version.displayName).tag(version.modelId)
                    }
                    Divider()
                    Text("Custom...").tag("__custom__")
                }
                .onChange(of: selectedModelId) { _, newValue in
                    if newValue == "__custom__" {
                        isCustomMode = true
                        customModelId = ""
                    }
                }
            }

            // Row 3: Description
            Text(isCustomMode ? "Enter a custom model identifier" : selectedFamily.description)
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

    private func syncFromModelId() {
        if let fam = family(for: selectedModelId) {
            if selectedFamily != fam {
                selectedFamily = fam
            }
            isCustomMode = false
        } else if !selectedModelId.isEmpty && selectedModelId != "__custom__" {
            isCustomMode = true
            customModelId = selectedModelId
        }
    }
}
