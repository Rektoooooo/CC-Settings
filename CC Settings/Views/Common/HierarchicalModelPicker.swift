import SwiftUI

struct HierarchicalModelPicker: View {
    @Binding var selectedModelId: String
    @State private var selectedFamily: ModelFamily = .sonnet
    @State private var isCustomMode: Bool = false
    @State private var customModelId: String = ""

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
                    if let latest = versions(for: newFamily).first(where: { $0.isLatest }),
                       selectedModelId != latest.modelId {
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
                    ForEach(versions(for: selectedFamily)) { version in
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
