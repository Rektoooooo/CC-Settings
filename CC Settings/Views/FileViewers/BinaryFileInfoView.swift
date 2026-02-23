import SwiftUI

struct BinaryFileInfoView: View {
    let file: ClaudeFile

    @State private var hexPreview: String = ""
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            FileViewerToolbar(file: file, readOnly: true, hasChanges: false)
            ReadOnlyBanner(message: "Binary file — viewing metadata and hex preview.")
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metadataGrid
                    hexSection
                }
                .padding(16)
            }
        }
        .onAppear { loadHexPreview() }
        .onChange(of: file.id) { _, _ in loadHexPreview() }
    }

    // MARK: - Metadata Grid

    private var metadataGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File Info")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Name").font(.caption).foregroundColor(.secondary)
                    Text(file.name).font(.caption.monospaced())
                }
                GridRow {
                    Text("Size").font(.caption).foregroundColor(.secondary)
                    Text(file.formattedSize).font(.caption.monospaced())
                }
                GridRow {
                    Text("Type").font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: file.type.icon)
                            .foregroundColor(file.type.color)
                            .font(.caption)
                        Text(file.type.rawValue.capitalized)
                            .font(.caption.monospaced())
                    }
                }
                GridRow {
                    Text("Modified").font(.caption).foregroundColor(.secondary)
                    Text(file.formattedDate).font(.caption.monospaced())
                }
                GridRow {
                    Text("Path").font(.caption).foregroundColor(.secondary)
                    Text(file.path.path)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                if file.isSymlink, let target = file.symlinkTarget {
                    GridRow {
                        Text("Symlink").font(.caption).foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                            Text(target)
                                .font(.caption.monospaced())
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding(12)
        .glassContainer()
    }

    // MARK: - Hex Preview

    private var hexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hex Preview")
                    .font(.headline)
                Text("(first 256 bytes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Reading bytes...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(24)
            } else if hexPreview.isEmpty {
                Text("Unable to read file data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(hexPreview)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                }
                .glassContainer()
            }
        }
    }

    // MARK: - Loading

    private func loadHexPreview() {
        isLoading = true
        let url = file.path
        Task.detached {
            let preview = BinaryFileInfoView.buildHexPreview(from: url, maxBytes: 256)
            await MainActor.run {
                hexPreview = preview
                isLoading = false
            }
        }
    }

    /// Build an xxd-format hex preview: offset: hex bytes  ascii
    nonisolated static func buildHexPreview(from url: URL, maxBytes: Int) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        let data = handle.readData(ofLength: maxBytes)
        handle.closeFile()

        guard !data.isEmpty else { return "" }

        var lines: [String] = []
        let bytesPerLine = 16

        for offset in stride(from: 0, to: data.count, by: bytesPerLine) {
            let end = min(offset + bytesPerLine, data.count)
            let chunk = data[offset..<end]

            // Offset
            let offsetStr = String(format: "%08x", offset)

            // Hex bytes (two groups of 8)
            var hexParts: [String] = []
            for (i, byte) in chunk.enumerated() {
                hexParts.append(String(format: "%02x", byte))
                if i == 7 {
                    hexParts.append("")  // extra space between groups
                }
            }
            let hexStr = hexParts.joined(separator: " ")
            // Pad to fixed width
            let fullHexWidth = 16 * 3 + 1  // "xx " * 16 + extra space
            let paddedHex = hexStr.padding(toLength: fullHexWidth, withPad: " ", startingAt: 0)

            // ASCII
            let ascii = chunk.map { byte -> Character in
                (0x20...0x7E).contains(byte) ? Character(UnicodeScalar(byte)) : "."
            }
            let asciiStr = String(ascii)

            lines.append("\(offsetStr): \(paddedHex) \(asciiStr)")
        }

        return lines.joined(separator: "\n")
    }
}
