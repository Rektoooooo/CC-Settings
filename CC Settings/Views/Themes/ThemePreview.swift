import SwiftUI

/// A mock Claude Code session rendered with a theme's resolved palette (base palette plus the
/// theme's overrides), so edits show exactly which colour key paints what.
struct ThemePreview: View {
    let theme: ThemeFile

    private var isDark: Bool { theme.base.hasPrefix("dark") }
    private var surface: Color { isDark ? Color(white: 0.09) : Color.white }

    private func color(_ key: String) -> Color {
        ThemeColorValue.color(theme.effectiveValue(for: key)) ?? (isDark ? .white : .black)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("\u{273B}").foregroundColor(color("claude"))
                Text("Claude Code").foregroundColor(color("text")).bold()
                Text("v2.1").foregroundColor(color("inactive"))
            }

            promptBox

            VStack(alignment: .leading, spacing: 1) {
                diffLine(1, marker: " ", text: "func greet() {", kind: nil)
                diffLine(2, marker: "-", text: "    print(\"hello\")", kind: .removed)
                diffLine(2, marker: "+", text: "    print(\"hello, world\")", kind: .added)
                diffLine(3, marker: " ", text: "}", kind: nil)
            }

            HStack(spacing: 8) {
                Text("! git status")
                    .foregroundColor(color("text"))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(color("bashBorder"), lineWidth: 1))
                Text("plan mode on").foregroundColor(color("planMode"))
                Text("auto-accept edits").foregroundColor(color("autoAccept"))
            }

            HStack(spacing: 14) {
                Label("saved", systemImage: "checkmark.circle.fill").foregroundColor(color("success"))
                Label("careful", systemImage: "exclamationmark.triangle.fill").foregroundColor(color("warning"))
                Label("denied", systemImage: "xmark.circle.fill").foregroundColor(color("error"))
                Label("allow Bash?", systemImage: "lock.fill").foregroundColor(color("permission"))
            }
            .font(.caption2)

            HStack(spacing: 10) {
                Text("tip: press / for commands").foregroundColor(color("subtle"))
                Text("suggestion").foregroundColor(color("suggestion"))
                Text("remember").foregroundColor(color("remember"))
            }
            .font(.caption2)

            Spacer(minLength: 0)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var promptBox: some View {
        HStack(spacing: 6) {
            Text(">").foregroundColor(color("promptBorder"))
            Text("fix the greeting").foregroundColor(color("text"))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(color("userMessageBackground").opacity(isDark ? 0.25 : 1))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(color("promptBorder"), lineWidth: 1))
    }

    private enum DiffKind { case added, removed }

    private func diffLine(_ number: Int, marker: String, text: String, kind: DiffKind?) -> some View {
        let background: Color = {
            switch kind {
            case .added: return color("diffAddedDimmed")
            case .removed: return color("diffRemovedDimmed")
            case nil: return .clear
            }
        }()
        let foreground: Color = {
            switch kind {
            case .added: return color("diffAddedWord")
            case .removed: return color("diffRemovedWord")
            case nil: return color("text")
            }
        }()
        return HStack(spacing: 0) {
            Text(String(format: "%2d", number)).foregroundColor(color("inactive")).frame(width: 22, alignment: .trailing)
            Text(" \(marker) ").foregroundColor(foreground)
            Text(text).foregroundColor(foreground)
            Spacer(minLength: 0)
        }
        .background(background.opacity(kind == nil ? 0 : (isDark ? 0.5 : 1)))
    }
}
