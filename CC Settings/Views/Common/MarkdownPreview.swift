import SwiftUI
import Markdown

struct MarkdownPreview: View {
    let markdown: String

    var body: some View {
        let cleaned = Self.stripFrontmatter(markdown)
        let document = Document(parsing: cleaned)
        VStack(alignment: .leading, spacing: 10) {
            renderMarkup(document)
        }
        .textSelection(.enabled)
    }

    /// Strips YAML frontmatter (between `---` delimiters) from the beginning of markdown content.
    private static func stripFrontmatter(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return text }

        let lines = trimmed.components(separatedBy: "\n")
        guard lines.count > 1 else { return text }

        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                let remaining = lines[(i + 1)...].joined(separator: "\n")
                return remaining.trimmingCharacters(in: .newlines)
            }
        }
        return text
    }

    // MARK: - Top-Level Markup Dispatch

    @ViewBuilder
    private func renderMarkup(_ markup: any Markup) -> some View {
        ForEach(Array(markup.children.enumerated()), id: \.offset) { _, child in
            AnyView(renderBlock(child))
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: any Markup) -> some View {
        if let heading = block as? Heading {
            renderHeading(heading)
        } else if let paragraph = block as? Paragraph {
            renderParagraph(paragraph)
        } else if let codeBlock = block as? CodeBlock {
            renderCodeBlock(codeBlock)
        } else if let blockQuote = block as? BlockQuote {
            renderBlockQuote(blockQuote)
        } else if let unorderedList = block as? UnorderedList {
            renderUnorderedList(unorderedList)
        } else if let orderedList = block as? OrderedList {
            renderOrderedList(orderedList)
        } else if block is ThematicBreak {
            Divider()
                .padding(.vertical, 6)
        } else if let table = block as? Markdown.Table {
            renderTable(table)
        } else if let htmlBlock = block as? HTMLBlock {
            Text(htmlBlock.rawHTML)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(6)
        } else {
            ForEach(Array(block.children.enumerated()), id: \.offset) { _, child in
                AnyView(renderBlock(child))
            }
        }
    }

    // MARK: - Headings

    @ViewBuilder
    private func renderHeading(_ heading: Heading) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let attributed = inlineAttributedString(from: heading.children)
            Text(attributed)
                .font(.system(size: headingSize(for: heading.level), weight: headingWeight(for: heading.level)))
                .padding(.top, headingTopPadding(for: heading.level))

            if heading.level <= 2 {
                Divider()
            }
        }
    }

    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 26
        case 2: return 21
        case 3: return 17
        case 4: return 15
        default: return 13
        }
    }

    private func headingWeight(for level: Int) -> Font.Weight {
        switch level {
        case 1: return .bold
        case 2: return .bold
        case 3: return .semibold
        default: return .medium
        }
    }

    private func headingTopPadding(for level: Int) -> CGFloat {
        switch level {
        case 1: return 12
        case 2: return 10
        case 3: return 6
        default: return 4
        }
    }

    // MARK: - Paragraphs

    @ViewBuilder
    private func renderParagraph(_ paragraph: Paragraph) -> some View {
        let attributed = inlineAttributedString(from: paragraph.children)
        Text(attributed)
            .font(.body)
            .lineSpacing(3)
    }

    // MARK: - Code Blocks

    @ViewBuilder
    private func renderCodeBlock(_ codeBlock: CodeBlock) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lang = codeBlock.language, !lang.isEmpty {
                Text(lang)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 6))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(codeBlock.code.trimmingCharacters(in: .newlines))
                    .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: codeBlock.language != nil ? 0 : 6,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 6
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: codeBlock.language != nil ? 0 : 6,
                    bottomLeadingRadius: 6,
                    bottomTrailingRadius: 6,
                    topTrailingRadius: 6
                )
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Block Quotes

    @ViewBuilder
    private func renderBlockQuote(_ blockQuote: BlockQuote) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blockQuote.children.enumerated()), id: \.offset) { _, child in
                    if let paragraph = child as? Paragraph {
                        let attributed = inlineAttributedString(from: paragraph.children)
                        Text(attributed)
                            .font(.body)
                            .italic()
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    } else {
                        AnyView(renderBlock(child))
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 2)
    }

    // MARK: - Unordered Lists

    private func renderUnorderedList(_ list: UnorderedList, depth: Int = 0) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(list.children.enumerated()), id: \.offset) { _, item in
                if let listItem = item as? ListItem {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(bulletChar(for: depth))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 14, alignment: .center)
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(listItem.children.enumerated()), id: \.offset) { _, child in
                                if let paragraph = child as? Paragraph {
                                    let attributed = inlineAttributedString(from: paragraph.children)
                                    Text(attributed)
                                        .font(.body)
                                } else if let nestedUL = child as? UnorderedList {
                                    AnyView(renderUnorderedList(nestedUL, depth: depth + 1)
                                        .padding(.leading, 4))
                                } else if let nestedOL = child as? OrderedList {
                                    AnyView(renderOrderedList(nestedOL)
                                        .padding(.leading, 4))
                                } else {
                                    AnyView(renderBlock(child))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func bulletChar(for depth: Int) -> String {
        switch depth % 3 {
        case 0: return "\u{2022}"   // bullet
        case 1: return "\u{25E6}"   // white bullet
        default: return "\u{2023}"  // triangular bullet
        }
    }

    // MARK: - Ordered Lists

    private func renderOrderedList(_ list: OrderedList) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(list.children.enumerated()), id: \.offset) { index, item in
                if let listItem = item as? ListItem {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(index + 1).")
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 26, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(listItem.children.enumerated()), id: \.offset) { _, child in
                                if let paragraph = child as? Paragraph {
                                    let attributed = inlineAttributedString(from: paragraph.children)
                                    Text(attributed)
                                        .font(.body)
                                } else if let nestedUL = child as? UnorderedList {
                                    AnyView(renderUnorderedList(nestedUL)
                                        .padding(.leading, 4))
                                } else if let nestedOL = child as? OrderedList {
                                    AnyView(renderOrderedList(nestedOL)
                                        .padding(.leading, 4))
                                } else {
                                    AnyView(renderBlock(child))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tables

    @ViewBuilder
    private func renderTable(_ table: Markdown.Table) -> some View {
        let headerCells = extractTableRow(table.head)
        let bodyRows = table.body.children.map { row -> [AttributedString] in
            if let tableRow = row as? Markdown.Table.Row {
                return extractTableRow(tableRow)
            }
            return []
        }

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(headerCells.enumerated()), id: \.offset) { index, cell in
                    Text(cell)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if index < headerCells.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color.secondary.opacity(0.08))

            ForEach(Array(bodyRows.enumerated()), id: \.offset) { rowIndex, row in
                Divider().opacity(0.5)
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { cellIndex, cell in
                        Text(cell)
                            .font(.callout)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if cellIndex < row.count - 1 {
                            Divider().opacity(0.5)
                        }
                    }
                }
                .background(rowIndex % 2 == 1 ? Color.secondary.opacity(0.03) : Color.clear)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func extractTableRow(_ row: any Markup) -> [AttributedString] {
        return row.children.map { cell -> AttributedString in
            if let tableCell = cell as? Markdown.Table.Cell {
                return inlineAttributedString(from: tableCell.children.flatMap { markup -> [any Markup] in
                    if let paragraph = markup as? Paragraph {
                        return Array(paragraph.children)
                    }
                    return [markup]
                })
            }
            return AttributedString(cell.format())
        }
    }

    // MARK: - Inline Content to AttributedString

    private func inlineAttributedString(from children: some Sequence<any Markup>) -> AttributedString {
        var result = AttributedString()
        for child in children {
            result.append(inlineElement(child))
        }
        return result
    }

    private func inlineElement(_ markup: any Markup) -> AttributedString {
        if let text = markup as? Markdown.Text {
            return AttributedString(text.string)
        } else if let strong = markup as? Strong {
            var attributed = inlineAttributedString(from: strong.children)
            attributed.font = .body.bold()
            return attributed
        } else if let emphasis = markup as? Emphasis {
            var attributed = inlineAttributedString(from: emphasis.children)
            attributed.font = .body.italic()
            return attributed
        } else if let inlineCode = markup as? InlineCode {
            var attributed = AttributedString(" \(inlineCode.code) ")
            attributed.font = .system(.callout, design: .monospaced).weight(.medium)
            attributed.foregroundColor = .secondary
            attributed.backgroundColor = Color.secondary.opacity(0.1)
            return attributed
        } else if let link = markup as? Markdown.Link {
            var attributed = inlineAttributedString(from: link.children)
            if let destination = link.destination, let url = URL(string: destination) {
                attributed.link = url
                attributed.foregroundColor = .accentColor
                attributed.underlineStyle = .single
            }
            return attributed
        } else if let image = markup as? Markdown.Image {
            let altText = image.plainText
            var attributed = AttributedString("\u{1F5BC} \(altText)")
            attributed.foregroundColor = .secondary
            return attributed
        } else if markup is SoftBreak {
            return AttributedString(" ")
        } else if markup is LineBreak {
            return AttributedString("\n")
        } else if let strikethrough = markup as? Strikethrough {
            var attributed = inlineAttributedString(from: strikethrough.children)
            attributed.strikethroughStyle = .single
            attributed.foregroundColor = .secondary
            return attributed
        } else {
            return AttributedString(markup.format())
        }
    }
}
