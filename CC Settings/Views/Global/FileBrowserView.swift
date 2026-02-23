import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject private var configManager: ConfigurationManager

    @State private var files: [ClaudeFile] = []
    @State private var selectedFile: ClaudeFile?
    @State private var hasAutoSelected = false

    private var totalSize: String {
        let total = files.reduce(Int64(0)) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    var body: some View {
        HSplitView {
            // Left column: file list
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("~/.claude")
                            .font(.headline)
                        Text("Global configuration files")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        loadFiles()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Reload files")
                }
                .padding(12)

                Divider()

                // File list
                List(files, id: \.id, selection: $selectedFile) { file in
                    FileBrowserRow(file: file)
                        .tag(file)
                }
                .listStyle(.sidebar)

                Divider()

                // Footer
                HStack {
                    Text("\(files.count) file\(files.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(totalSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .frame(minWidth: 200, idealWidth: 260, maxWidth: 350)

            // Right column: file viewer
            if let file = selectedFile {
                FileViewerFactory.viewer(for: file, readOnly: false)
                    .frame(minWidth: 400)
            } else {
                EmptyContentPlaceholder(
                    icon: "doc.text.magnifyingglass",
                    title: "No File Selected",
                    subtitle: "Select a file from the list to view or edit."
                )
                .frame(minWidth: 400)
            }
        }
        .onAppear {
            loadFiles()
        }
    }

    private func loadFiles() {
        files = configManager.loadFilesFromClaudeDir().sorted { lhs, rhs in
            let lhsPriority = filePriority(lhs.name)
            let rhsPriority = filePriority(rhs.name)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        // Auto-select CLAUDE.md on first load
        if !hasAutoSelected {
            hasAutoSelected = true
            if let claudeMD = files.first(where: { $0.name == "CLAUDE.md" }) {
                selectedFile = claudeMD
            } else if let first = files.first {
                selectedFile = first
            }
        }
    }

    private func filePriority(_ name: String) -> Int {
        switch name.lowercased() {
        case "claude.md": return 0
        case "settings.json": return 1
        case "settings.local.json": return 2
        default: return 3
        }
    }
}

// MARK: - FileBrowserRow

private struct FileBrowserRow: View {
    let file: ClaudeFile

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.type.icon)
                .foregroundColor(file.type.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(file.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if file.modificationDate != nil {
                        Text(file.formattedDate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
