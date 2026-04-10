import SwiftUI

struct ClaudeMDRestoreSheet: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @Environment(\.dismiss) private var dismiss

    let onRestore: (String) -> Void

    @State private var selectedBackup: ConfigurationManager.ClaudeMDBackup?
    @State private var previewContent: String = ""

    private var backups: [ConfigurationManager.ClaudeMDBackup] {
        configManager.listClaudeMDBackups()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Restore from Backup")
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

            HSplitView {
                // Left: backup list
                List(backups, selection: $selectedBackup) { backup in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(backup.scope == "global" ? "Global" : backup.scope)
                            .font(.body)
                        Text(backup.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(backup.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .tag(backup)
                }
                .listStyle(.sidebar)
                .frame(minWidth: 180, idealWidth: 220)

                // Right: preview
                VStack(spacing: 0) {
                    PaneHeader(icon: "eye", title: "Preview")

                    if previewContent.isEmpty {
                        EmptyContentPlaceholder(
                            icon: "clock.arrow.counterclockwise",
                            title: "Select a Backup",
                            subtitle: "Choose a backup to preview its content"
                        )
                    } else {
                        ScrollView {
                            MarkdownPreview(markdown: previewContent)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .onChange(of: selectedBackup) {
                if let backup = selectedBackup,
                   let content = try? String(contentsOf: backup.url, encoding: .utf8) {
                    previewContent = content
                } else {
                    previewContent = ""
                }
            }

            Divider()

            HStack {
                if let backup = selectedBackup {
                    Text("Backup from \(backup.date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Restore") {
                    if !previewContent.isEmpty {
                        onRestore(previewContent)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedBackup == nil)
            }
            .padding()
        }
        .frame(minWidth: 500, idealWidth: 700, maxWidth: 900,
               minHeight: 400, idealHeight: 500, maxHeight: 700)
    }
}

extension ConfigurationManager.ClaudeMDBackup: Hashable {
    static func == (lhs: ConfigurationManager.ClaudeMDBackup, rhs: ConfigurationManager.ClaudeMDBackup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
