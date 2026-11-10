import Foundation

/// Line-preserving handling of a slash command's YAML frontmatter.
///
/// The app only models four keys (description, argument-hint, allowed-tools,
/// disallowed-tools). Everything else (model, hooks, comments, paths, ...) must survive a
/// save byte-for-byte, so the frontmatter is kept as raw lines grouped into key blocks and
/// only the blocks whose value the user actually changed are rewritten.
enum CommandFrontmatter {
    struct Block {
        var key: String?
        var lines: [String]
    }

    /// Groups frontmatter lines into top-level key blocks. A block is the `key:` line plus
    /// its continuation lines (indented lines, blank lines, `- item` lines, block scalars).
    static func blocks(_ lines: [String]) -> [Block] {
        var result: [Block] = []
        for line in lines {
            if let key = topLevelKey(line) {
                result.append(Block(key: key, lines: [line]))
            } else if line.hasPrefix("#") {
                result.append(Block(key: nil, lines: [line]))
            } else if result.isEmpty {
                result.append(Block(key: nil, lines: [line]))
            } else {
                result[result.count - 1].lines.append(line)
            }
        }
        return result
    }

    private static func topLevelKey(_ line: String) -> String? {
        guard let first = line.unicodeScalars.first,
              first.properties.isAlphabetic || first == "_",
              let colon = line.firstIndex(of: ":") else { return nil }
        let key = String(line[line.startIndex..<colon])
        guard key.unicodeScalars.allSatisfy({ $0.properties.isAlphabetic || ("0"..."9").contains($0) || $0 == "_" || $0 == "-" }) else { return nil }
        return key
    }

    private static func inlineValue(_ block: Block) -> String {
        guard let first = block.lines.first, let colon = first.firstIndex(of: ":") else { return "" }
        return String(first[first.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
    }

    private static func isBlockScalarIndicator(_ s: String) -> Bool {
        s.range(of: "^[|>][+-]?[0-9]?[+-]?$", options: .regularExpression) != nil
    }

    /// Single-line view of a scalar key (`description: text`, or a `|` / `>` block scalar,
    /// or a multi-line plain scalar), as shown in the editor.
    static func scalarValue(_ block: Block) -> String {
        let inline = inlineValue(block)
        let rest = block.lines.dropFirst().map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if inline.isEmpty || isBlockScalarIndicator(inline) {
            return rest.joined(separator: " ")
        }
        return ([inline] + rest).joined(separator: " ")
    }

    /// List view of a tools key: `a, b`, `[a, b]` or a YAML list of `- item` lines.
    static func listValue(_ block: Block) -> [String] {
        var inline = inlineValue(block)
        if !inline.isEmpty {
            if inline.hasPrefix("["), inline.hasSuffix("]") {
                inline = String(inline.dropFirst().dropLast())
            }
            return inline.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        return block.lines.dropFirst().compactMap { line -> String? in
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("-") else { return nil }
            let item = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
            return item.isEmpty ? nil : item
        }
    }

    /// Reads the four modeled values out of raw frontmatter lines.
    static func modeledValues(_ lines: [String]) -> (description: String, argumentHint: String, allowed: [String], disallowed: [String]) {
        var d = "", h = "", a: [String] = [], x: [String] = []
        var seen = Set<String>()
        for block in blocks(lines) {
            guard let key = block.key, seen.insert(key).inserted else { continue }
            switch key {
            case "description": d = scalarValue(block)
            case "argument-hint": h = scalarValue(block)
            case "allowed-tools": a = listValue(block)
            case "disallowed-tools": x = listValue(block)
            default: break
            }
        }
        return (d, h, a, x)
    }

    /// Returns `lines` with only the changed modeled keys rewritten (whole block replaced,
    /// continuation lines included) or removed/appended. Unchanged blocks, and every
    /// unmodeled line, are returned untouched.
    static func apply(to lines: [String], description: String, argumentHint: String,
                      allowedTools: [String], disallowedTools: [String]) -> [String] {
        var result = blocks(lines)

        func update(key: String, newText: String, isUnchanged: (Block) -> Bool) {
            if let index = result.firstIndex(where: { $0.key == key }) {
                if isUnchanged(result[index]) { return }
                if newText.isEmpty {
                    result.remove(at: index)
                } else {
                    result[index].lines = ["\(key): \(newText)"]
                }
            } else if !newText.isEmpty {
                result.append(Block(key: key, lines: ["\(key): \(newText)"]))
            }
        }

        update(key: "description", newText: description) { scalarValue($0) == description }
        update(key: "argument-hint", newText: argumentHint) { scalarValue($0) == argumentHint }
        update(key: "allowed-tools", newText: allowedTools.joined(separator: ", ")) { listValue($0) == allowedTools }
        update(key: "disallowed-tools", newText: disallowedTools.joined(separator: ", ")) { listValue($0) == disallowedTools }

        return result.flatMap(\.lines)
    }
}
