import SwiftUI

struct ClaudeMDInsertMenu: View {
    @Binding var content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insert")
                .font(.headline)
                .padding(.horizontal, 4)

            // Structure section
            VStack(alignment: .leading, spacing: 4) {
                Text("Structure")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                HStack(spacing: 4) {
                    insertButton("H1", icon: "textformat.size.larger") {
                        append("\n# Heading\n")
                    }
                    insertButton("H2", icon: "textformat.size") {
                        append("\n## Heading\n")
                    }
                    insertButton("H3", icon: "textformat.size.smaller") {
                        append("\n### Heading\n")
                    }
                }
            }

            Divider()

            // Content section
            VStack(alignment: .leading, spacing: 4) {
                Text("Content")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    insertButton("Code Block", icon: "chevron.left.forwardslash.chevron.right") {
                        append("\n```\n# Code here\n```\n")
                    }
                    insertButton("Bullet List", icon: "list.bullet") {
                        append("\n- Item 1\n- Item 2\n- Item 3\n")
                    }
                    insertButton("Numbered List", icon: "list.number") {
                        append("\n1. First\n2. Second\n3. Third\n")
                    }
                    insertButton("Table", icon: "tablecells") {
                        append("\n| Column 1 | Column 2 |\n|----------|----------|\n| Value 1  | Value 2  |\n")
                    }
                }
            }

            Divider()

            // CLAUDE.md Sections
            VStack(alignment: .leading, spacing: 4) {
                Text("CLAUDE.md Sections")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)

                ForEach(claudeMDSections) { section in
                    insertButton(section.name, icon: section.icon) {
                        append("\n" + section.content)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    private func insertButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func append(_ text: String) {
        if content.isEmpty {
            content = text.trimmingCharacters(in: .newlines) + "\n"
        } else if content.hasSuffix("\n") {
            content += text.trimmingCharacters(in: .newlines) + "\n"
        } else {
            content += text
        }
    }
}
