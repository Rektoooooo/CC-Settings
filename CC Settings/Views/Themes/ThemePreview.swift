import SwiftUI

/// A mock Claude Code "Edit file" panel that renders sample Swift code with
/// diff markers and syntax highlighting, using the theme's colors. Modeled
/// after how Claude Code renders code edits in the terminal.
struct ThemePreview: View {
    let theme: ThemeFile

    /// ANSI-only themes don't paint background stripes across the diff line.
    private var paintsDiffBackground: Bool {
        !theme.id.contains("ansi")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — mimics Claude Code's file-edit header
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundColor(accent)
                Text("theme-demo.swift")
                    .foregroundColor(foreground)
                    .font(.caption.monospaced())
            }
            .padding(.bottom, 8)

            // Code snippet with diff lines
            VStack(alignment: .leading, spacing: 1) {
                codeLine(1, kind: .normal, segments: [
                    (.keyword, "import"), (.foreground, " "), (.type, "Foundation"),
                ])
                codeLine(2, kind: .normal, segments: [(.foreground, "")])

                codeLine(3, kind: .removed, segments: [
                    (.comment, "// ThemeDemo — VS Code-style colors"),
                ])
                codeLine(3, kind: .added, segments: [
                    (.comment, "// ThemeDemo — palette preview"),
                ])

                codeLine(4, kind: .normal, segments: [
                    (.keyword, "struct"), (.foreground, " "), (.type, "ThemeDemo"),
                    (.foreground, " {"),
                ])

                codeLine(5, kind: .removed, segments: [
                    (.foreground, "    "), (.keyword, "let"), (.foreground, " name: "),
                    (.type, "String"), (.foreground, " = "), (.string, "\"solarized-light\""),
                ])
                codeLine(5, kind: .added, segments: [
                    (.foreground, "    "), (.keyword, "let"), (.foreground, " name: "),
                    (.type, "String"), (.foreground, " = "), (.string, "\"dracula-dark\""),
                ])

                codeLine(6, kind: .normal, segments: [
                    (.foreground, "    "), (.keyword, "let"), (.foreground, " colorCount: "),
                    (.type, "Int"), (.foreground, " = "), (.number, "256"),
                ])

                codeLine(7, kind: .normal, segments: [(.foreground, "}")])
            }

            // Status lines (success / warning / error)
            HStack(spacing: 14) {
                Label("saved", systemImage: "checkmark.circle.fill")
                    .foregroundColor(success)
                Label("warning", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(warning)
                Label("permission denied", systemImage: "xmark.circle.fill")
                    .foregroundColor(errorColor)
            }
            .font(.caption2)
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .font(.system(.caption, design: .monospaced))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Diff line rendering

    private enum LineKind { case normal, added, removed }
    private enum SegmentKind { case foreground, comment, keyword, string, number, function, type }

    @ViewBuilder
    private func codeLine(_ lineNumber: Int, kind: LineKind, segments: [(SegmentKind, String)]) -> some View {
        let marker: String = {
            switch kind {
            case .normal: return " "
            case .added: return "+"
            case .removed: return "-"
            }
        }()
        // Diff stripe — only paints for non-ANSI themes. Lower opacity than the
        // text tint so the colored line content stays legible on top.
        let stripeColor: Color = {
            guard paintsDiffBackground else { return .clear }
            switch kind {
            case .normal: return .clear
            case .added: return success.opacity(0.18)
            case .removed: return errorColor.opacity(0.18)
            }
        }()
        // On diff lines, Claude Code tints the WHOLE LINE (line number, marker,
        // and every segment) with the diff color — syntax colors are dropped.
        let diffTint: Color? = {
            switch kind {
            case .normal: return nil
            case .added: return success
            case .removed: return errorColor
            }
        }()
        let lineNumberColor: Color = diffTint ?? muted
        let markerColor: Color = diffTint ?? muted

        HStack(spacing: 0) {
            Text(String(format: "%2d", lineNumber))
                .foregroundColor(lineNumberColor)
                .frame(width: 22, alignment: .trailing)
            Text(" \(marker) ")
                .foregroundColor(markerColor)
            ForEach(0..<segments.count, id: \.self) { i in
                Text(segments[i].1)
                    .foregroundColor(diffTint ?? color(for: segments[i].0))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(stripeColor)
    }

    // MARK: - Color resolution

    // Background / foreground come from the theme so the preview reflects the
    // theme's actual surface colors (white for light themes, dark for dark ones).
    // Themes that don't specify them — e.g. Auto — fall back to the macOS appearance.
    private var background: Color { resolved(\.background, fallback: Color(NSColor.textBackgroundColor)) }
    private var foreground: Color { resolved(\.foreground, fallback: Color(NSColor.labelColor)) }
    private var accent: Color { resolved(\.accent, fallback: foreground) }
    private var success: Color { resolved(\.success, fallback: .green) }
    private var errorColor: Color { resolved(\.error, fallback: .red) }
    private var warning: Color { resolved(\.warning, fallback: .orange) }
    private var muted: Color { resolved(\.muted, fallback: .secondary) }

    private func resolved(_ path: WritableKeyPath<ThemeColors, String?>, fallback: Color) -> Color {
        guard let hex = theme.colors[keyPath: path], Color.isValidHex(hex) else {
            return fallback
        }
        return Color(hex: hex)
    }

    private func color(for kind: SegmentKind) -> Color {
        switch kind {
        case .foreground: return foreground
        case .comment:    return resolved(\.comment, fallback: muted)
        case .keyword:    return resolved(\.keyword, fallback: foreground)
        case .string:     return resolved(\.string, fallback: foreground)
        case .number:     return resolved(\.number, fallback: foreground)
        case .function:   return resolved(\.function, fallback: foreground)
        case .type:       return resolved(\.type, fallback: foreground)
        }
    }
}
