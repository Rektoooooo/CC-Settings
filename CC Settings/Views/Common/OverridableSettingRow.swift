import SwiftUI

struct OverridableSettingRow<Content: View>: View {
    let title: String
    var description: String? = nil
    let globalSummary: String
    let isOverridden: Bool
    let onToggleOverride: (Bool) -> Void
    @ViewBuilder let content: () -> Content

    @State private var localOverride: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(title)
                Spacer()
                HStack(spacing: 6) {
                    Text(localOverride ? "Custom" : "Inherited")
                        .font(.caption)
                        .foregroundColor(localOverride ? .accentColor : .secondary)
                    Toggle("", isOn: $localOverride)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .onChange(of: localOverride) {
                            if localOverride != isOverridden {
                                onToggleOverride(localOverride)
                            }
                        }
                }
            }

            if localOverride {
                content()
            } else {
                Text(globalSummary)
                    .foregroundColor(.secondary.opacity(0.6))
                    .italic()
            }

            if let description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear { localOverride = isOverridden }
        .onChange(of: isOverridden) { localOverride = isOverridden }
    }
}
