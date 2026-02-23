import SwiftUI

@MainActor
final class HUDState: ObservableObject {
    @Published var isExpanded: Bool

    init(isExpanded: Bool) {
        self.isExpanded = isExpanded
    }
}

struct HUDContentView: View {
    @ObservedObject var configManager = ConfigurationManager.shared
    @ObservedObject var hudState: HUDState

    var body: some View {
        Group {
            if hudState.isExpanded {
                expandedView
            } else {
                compactView
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Compact View

    private var compactView: some View {
        HStack(spacing: 8) {
            modelIcon
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text(displayName(for: configManager.settings.model))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 4)

            if configManager.settings.alwaysThinkingEnabled == true {
                thinkingIndicator
            }

            expandToggleButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 200, height: 44)
        .contentShape(Rectangle())
    }

    // MARK: - Expanded View

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with model name and collapse button
            HStack {
                modelIcon
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(displayName(for: configManager.settings.model))
                        .font(.system(size: 13, weight: .semibold))

                    if let modelFamily = family(for: configManager.settings.model) {
                        Text(modelFamily.description)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                expandToggleButton
            }

            Divider()
                .opacity(0.5)

            // Thinking toggle
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: thinkingBinding) {
                    Label("Extended Thinking", systemImage: "brain")
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                if configManager.settings.alwaysThinkingEnabled == true {
                    HStack(spacing: 6) {
                        Text("Budget:")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Slider(
                            value: budgetBinding,
                            in: 1024...32768,
                            step: 1024
                        )
                        .controlSize(.small)

                        Text("\(configManager.settings.thinkingBudgetTokens ?? 10000)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }

            Divider()
                .opacity(0.5)

            // Model ID info
            HStack(spacing: 8) {
                Label(configManager.settings.model, systemImage: "tag")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer()
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    // MARK: - Components

    private var modelIcon: some View {
        Group {
            if let modelFamily = family(for: configManager.settings.model) {
                Image(systemName: modelFamily.icon)
            } else {
                Image(systemName: "cpu")
            }
        }
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 3) {
            Image(systemName: "brain")
                .font(.system(size: 8))
            Text("T")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(.purple)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.purple.opacity(0.15), in: Capsule())
    }

    private var expandToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                hudState.isExpanded.toggle()
            }
            if let panel = NSApp.windows.compactMap({ $0 as? HUDPanel }).first {
                panel.updateForExpandedState()
            }
        } label: {
            Image(systemName: hudState.isExpanded ? "chevron.up.circle" : "chevron.down.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bindings

    private var thinkingBinding: Binding<Bool> {
        Binding(
            get: { configManager.settings.alwaysThinkingEnabled == true },
            set: { newValue in
                configManager.settings.alwaysThinkingEnabled = newValue ? true : nil
                if newValue && configManager.settings.thinkingBudgetTokens == nil {
                    configManager.settings.thinkingBudgetTokens = 10000
                }
                if !newValue {
                    configManager.settings.thinkingBudgetTokens = nil
                }
                configManager.saveSettings()
            }
        )
    }

    private var budgetBinding: Binding<Double> {
        Binding(
            get: { Double(configManager.settings.thinkingBudgetTokens ?? 10000) },
            set: { newValue in
                configManager.settings.thinkingBudgetTokens = Int(newValue)
                configManager.saveSettings()
            }
        )
    }
}
