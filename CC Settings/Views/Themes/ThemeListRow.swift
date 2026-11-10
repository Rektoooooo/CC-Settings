import SwiftUI

/// One row in the Themes sidebar list. Shows the filename plus a swatch strip
/// summarizing the theme's key colors, with an "Active" badge when this theme
/// is the one stored in `settings.json:theme`.
struct ThemeListRow: View {
    let theme: ThemeFile
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            swatchStrip

            VStack(alignment: .leading, spacing: 2) {
                Text(theme.name)
                    .font(.body)
                    .lineLimit(1)
                Text(theme.name != theme.id ? "\(theme.id) · base \(theme.base)" : "base \(theme.base)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isActive {
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

    @ViewBuilder
    private var swatchStrip: some View {
        let keys = ["claude", "permission", "success", "error", "warning", "promptBorder"]
        HStack(spacing: 2) {
            ForEach(keys, id: \.self) { key in
                RoundedRectangle(cornerRadius: 2)
                    .fill(ThemeColorValue.color(theme.effectiveValue(for: key)) ?? Color.gray.opacity(0.25))
                    .frame(width: 12, height: 18)
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
