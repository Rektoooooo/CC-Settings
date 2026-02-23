import SwiftUI

struct DiffView: View {
    let diff: String
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            if diff.isEmpty {
                EmptyContentPlaceholder(
                    icon: "doc.text.magnifyingglass",
                    title: "No Changes",
                    subtitle: "Select a file or commit to view its diff"
                )
            } else {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(additionCount) additions, \(deletionCount) deletions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(parsedLines.enumerated()), id: \.offset) { _, line in
                            DiffLineView(line: line)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Parsing

    private var parsedLines: [DiffLine] {
        DiffParser.parse(diff)
    }

    private var additionCount: Int {
        parsedLines.filter { $0.type == .addition }.count
    }

    private var deletionCount: Int {
        parsedLines.filter { $0.type == .deletion }.count
    }
}

// MARK: - DiffLine Model

struct DiffLine {
    enum LineType {
        case header
        case hunkHeader
        case addition
        case deletion
        case context
    }

    let text: String
    let type: LineType
    let oldLineNumber: Int?
    let newLineNumber: Int?
}

// MARK: - DiffParser

enum DiffParser {
    static func parse(_ diff: String) -> [DiffLine] {
        let rawLines = diff.components(separatedBy: "\n")
        var result: [DiffLine] = []
        var oldLine = 0
        var newLine = 0

        for raw in rawLines {
            if raw.hasPrefix("diff ") || raw.hasPrefix("index ") ||
               raw.hasPrefix("---") || raw.hasPrefix("+++") {
                result.append(DiffLine(text: raw, type: .header, oldLineNumber: nil, newLineNumber: nil))
            } else if raw.hasPrefix("@@") {
                // Parse hunk header for line numbers
                let numbers = parseHunkHeader(raw)
                oldLine = numbers.oldStart
                newLine = numbers.newStart
                result.append(DiffLine(text: raw, type: .hunkHeader, oldLineNumber: nil, newLineNumber: nil))
            } else if raw.hasPrefix("+") {
                result.append(DiffLine(text: String(raw.dropFirst()), type: .addition, oldLineNumber: nil, newLineNumber: newLine))
                newLine += 1
            } else if raw.hasPrefix("-") {
                result.append(DiffLine(text: String(raw.dropFirst()), type: .deletion, oldLineNumber: oldLine, newLineNumber: nil))
                oldLine += 1
            } else if raw.hasPrefix(" ") {
                result.append(DiffLine(text: String(raw.dropFirst()), type: .context, oldLineNumber: oldLine, newLineNumber: newLine))
                oldLine += 1
                newLine += 1
            } else if !raw.isEmpty {
                result.append(DiffLine(text: raw, type: .context, oldLineNumber: nil, newLineNumber: nil))
            }
        }

        return result
    }

    private static func parseHunkHeader(_ line: String) -> (oldStart: Int, newStart: Int) {
        // Format: @@ -oldStart[,count] +newStart[,count] @@
        let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return (1, 1)
        }

        let oldStart = Int(line[Range(match.range(at: 1), in: line)!]) ?? 1
        let newStart = Int(line[Range(match.range(at: 2), in: line)!]) ?? 1
        return (oldStart, newStart)
    }
}

// MARK: - DiffLineView

private struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            // Line numbers gutter
            switch line.type {
            case .header, .hunkHeader:
                Text("")
                    .frame(width: 80, alignment: .leading)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            default:
                HStack(spacing: 0) {
                    Text(line.oldLineNumber.map { "\($0)" } ?? "")
                        .frame(width: 38, alignment: .trailing)
                    Text(line.newLineNumber.map { "\($0)" } ?? "")
                        .frame(width: 38, alignment: .trailing)
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.trailing, 4)
            }

            // Prefix character
            Text(prefixChar)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 14, alignment: .center)

            // Content
            Text(line.text)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(textColor)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 0.5)
        .background(backgroundColor)
    }

    private var prefixChar: String {
        switch line.type {
        case .addition: return "+"
        case .deletion: return "-"
        case .hunkHeader: return ""
        default: return " "
        }
    }

    private var textColor: Color {
        switch line.type {
        case .header: return .secondary
        case .hunkHeader: return .cyan
        case .addition: return .green
        case .deletion: return .red
        case .context: return .primary
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .addition: return .green.opacity(0.1)
        case .deletion: return .red.opacity(0.1)
        case .hunkHeader: return .cyan.opacity(0.05)
        default: return .clear
        }
    }
}
