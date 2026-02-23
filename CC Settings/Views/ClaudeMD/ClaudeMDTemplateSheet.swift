import SwiftUI

struct ClaudeMDTemplateSheet: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: ClaudeMDTemplate? = claudeMDTemplates.first

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create from Template")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Content
            HSplitView {
                // Left: template list
                List(claudeMDTemplates, selection: $selectedTemplate) { template in
                    HStack(spacing: 10) {
                        Image(systemName: template.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(.body)
                            Text(template.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(template)
                    .contentShape(Rectangle())
                }
                .listStyle(.sidebar)
                .frame(minWidth: 200, idealWidth: 240)

                // Right: preview
                VStack(spacing: 0) {
                    PaneHeader(icon: "eye", title: "Preview")

                    if let template = selectedTemplate {
                        if template.content.isEmpty {
                            EmptyContentPlaceholder(
                                icon: "doc",
                                title: "Blank Template",
                                subtitle: "Starts with an empty CLAUDE.md file"
                            )
                        } else {
                            ScrollView {
                                MarkdownPreview(markdown: template.content)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } else {
                        EmptyContentPlaceholder(
                            icon: "doc.text",
                            title: "Select a Template",
                            subtitle: "Choose a template from the list"
                        )
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                if let template = selectedTemplate {
                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    if let template = selectedTemplate {
                        onSelect(template.content)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedTemplate == nil)
            }
            .padding()
        }
        .frame(minWidth: 500, idealWidth: 700, maxWidth: 900,
               minHeight: 400, idealHeight: 500, maxHeight: 700)
    }
}

extension ClaudeMDTemplate: Hashable {
    static func == (lhs: ClaudeMDTemplate, rhs: ClaudeMDTemplate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
