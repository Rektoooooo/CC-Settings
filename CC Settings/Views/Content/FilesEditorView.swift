import SwiftUI

enum FileContentItem: Hashable {
    case general
    case project(String)
    case folder(String)

    var title: String {
        switch self {
        case .general: return "Global Files"
        case .project: return "Project Files"
        case .folder(let name): return name.capitalized
        }
    }

    var icon: String {
        switch self {
        case .general: return "house"
        case .project: return "folder"
        case .folder(let name): return SubfolderEntry.icon(for: name)
        }
    }

    @MainActor
    var subtitle: String {
        switch self {
        case .general: return "~/.claude"
        case .project(let projectId):
            let path = ConfigurationManager.shared.projectOriginalPath(for: projectId)
            return path
        case .folder(let name): return "~/.claude/\(name)"
        }
    }
}

struct FilesEditorView: View {
    let contentItem: FileContentItem

    @EnvironmentObject private var configManager: ConfigurationManager

    @State private var files: [ClaudeFile] = []
    @State private var selectedFile: ClaudeFile?
    @State private var searchText: String = ""
    @State private var showAllItems = false

    private static let displayCap = 50

    private var filteredFiles: [ClaudeFile] {
        let sorted = files.sorted { lhs, rhs in
            let lhsPriority = filePriority(lhs.name)
            let rhsPriority = filePriority(rhs.name)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var displayedFiles: [ClaudeFile] {
        if showAllItems || filteredFiles.count <= Self.displayCap {
            return filteredFiles
        }
        return Array(filteredFiles.prefix(Self.displayCap))
    }

    private var isCapped: Bool {
        !showAllItems && filteredFiles.count > Self.displayCap
    }

    var body: some View {
        HSplitView {
            // Left column: file list
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: contentItem.icon)
                            .foregroundColor(.accentColor)
                        Text(contentItem.title)
                            .font(.headline)
                        Spacer()
                        Button {
                            loadFiles()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Reload files")
                    }
                    Text(contentItem.subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(12)

                // Search field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(8)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)

                Divider()
                    .padding(.top, 8)

                // File list
                List(displayedFiles, id: \.id, selection: $selectedFile) { file in
                    FileListRow(file: file)
                        .tag(file)
                }
                .listStyle(.sidebar)

                if isCapped {
                    Button {
                        showAllItems = true
                    } label: {
                        Text("Show all \(filteredFiles.count) items")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                }

                Divider()

                // Footer
                HStack {
                    Text("\(displayedFiles.count)\(isCapped ? " of \(filteredFiles.count)" : "") file\(filteredFiles.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
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
                    subtitle: "Select a file from the sidebar to view or edit."
                )
                .frame(minWidth: 400)
            }
        }
        .onAppear {
            loadFiles()
        }
        .onChange(of: contentItem) { _, _ in
            selectedFile = nil
            searchText = ""
            loadFiles()
        }
    }

    private func loadFiles() {
        showAllItems = false
        switch contentItem {
        case .general:
            files = configManager.loadFilesFromClaudeDir()
        case .project(let projectId):
            files = configManager.loadFilesForProject(projectId)
        case .folder(let name):
            files = configManager.loadFilesFromFolder(name)
        }

        // Auto-select first file if nothing selected
        if selectedFile == nil, let first = filteredFiles.first {
            selectedFile = first
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

// MARK: - FileListRow

private struct FileListRow: View {
    let file: ClaudeFile

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.type.icon)
                .foregroundColor(file.type.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(file.name)
                        .font(.body)
                        .lineLimit(1)

                    if file.isSymlink {
                        Image(systemName: file.isBrokenSymlink ? "exclamationmark.triangle.fill" : "arrow.right.circle")
                            .font(.caption2)
                            .foregroundColor(file.isBrokenSymlink ? .red : .orange)
                            .help(file.isBrokenSymlink ? "Broken symlink" : "Symbolic link")
                    }
                }

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

                if file.isSymlink, let target = file.symlinkTarget {
                    Text("→ \(target)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
