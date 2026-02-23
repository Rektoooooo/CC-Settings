import SwiftUI

struct DirectoryListingView: View {
    let file: ClaudeFile

    @State private var entries: [DirectoryEntry] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header toolbar
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                Text(file.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if !isLoading {
                    Text("\(entries.count) item\(entries.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassToolbar()

            ReadOnlyBanner(message: "Directory listing — \(file.path.path)")
            Divider()

            if isLoading {
                Spacer()
                ProgressView("Scanning directory...")
                    .font(.caption)
                Spacer()
            } else if entries.isEmpty {
                EmptyContentPlaceholder(
                    icon: "folder",
                    title: "Empty Directory",
                    subtitle: "This directory contains no items."
                )
            } else {
                List(entries) { entry in
                    DirectoryEntryRow(entry: entry)
                }
                .listStyle(.inset)
            }
        }
        .onAppear { loadEntries() }
        .onChange(of: file.id) { _, _ in loadEntries() }
    }

    private func loadEntries() {
        isLoading = true
        let url = file.path
        Task.detached {
            let result = DirectoryListingView.scanDirectory(at: url)
            await MainActor.run {
                entries = result
                isLoading = false
            }
        }
    }

    nonisolated static func scanDirectory(at url: URL) -> [DirectoryEntry] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var entries: [DirectoryEntry] = []
        for item in contents {
            let values = try? item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            let isDir = values?.isDirectory ?? false
            let size = Int64(values?.fileSize ?? 0)
            let type = FileType.detect(from: item)

            entries.append(DirectoryEntry(
                name: item.lastPathComponent,
                isDirectory: isDir,
                size: size,
                path: item.path,
                fileIcon: isDir ? "folder.fill" : type.icon,
                iconColor: isDir ? .blue : type.color
            ))
        }

        // Sort: directories first, then alphabetically
        entries.sort { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return entries
    }
}

// MARK: - DirectoryEntry

struct DirectoryEntry: Identifiable, Sendable {
    var id: String { path }
    let name: String
    let isDirectory: Bool
    let size: Int64
    let path: String
    let fileIcon: String
    let iconColor: Color
}

// MARK: - DirectoryEntryRow

private struct DirectoryEntryRow: View {
    let entry: DirectoryEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.fileIcon)
                .foregroundColor(entry.iconColor)
                .frame(width: 20)

            Text(entry.name)
                .font(.body)
                .lineLimit(1)

            Spacer()

            if !entry.isDirectory {
                Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
