import SwiftUI

struct ClaudeMDTemplateSheet: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: ClaudeMDTemplate? = claudeMDTemplates.first

    private var groupedTemplates: [(category: String, templates: [ClaudeMDTemplate])] {
        templateCategories.compactMap { category in
            let templates = claudeMDTemplates.filter { $0.category == category }
            return templates.isEmpty ? nil : (category, templates)
        }
    }

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
                // Left: template list grouped by category
                List(selection: $selectedTemplate) {
                    ForEach(groupedTemplates, id: \.category) { group in
                        Section(group.category) {
                            ForEach(group.templates) { template in
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
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(minWidth: 220, idealWidth: 260)

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

                Text("Your current CLAUDE.md will be backed up automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()

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
        .frame(minWidth: 600, idealWidth: 800, maxWidth: 1000,
               minHeight: 450, idealHeight: 550, maxHeight: 750)
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
