import SwiftUI

struct ClaudeFile: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let type: FileType
    let size: Int64
    let modificationDate: Date?
    let isSymlink: Bool
    let symlinkTarget: String?
    let isBrokenSymlink: Bool
    let isDirectory: Bool
    let directoryItemCount: Int

    init(
        id: String,
        name: String,
        path: URL,
        type: FileType,
        size: Int64,
        modificationDate: Date?,
        isSymlink: Bool = false,
        symlinkTarget: String? = nil,
        isBrokenSymlink: Bool = false,
        isDirectory: Bool = false,
        directoryItemCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.type = type
        self.size = size
        self.modificationDate = modificationDate
        self.isSymlink = isSymlink
        self.symlinkTarget = symlinkTarget
        self.isBrokenSymlink = isBrokenSymlink
        self.isDirectory = isDirectory
        self.directoryItemCount = directoryItemCount
    }

    var formattedSize: String {
        if isDirectory {
            return "\(directoryItemCount) item\(directoryItemCount == 1 ? "" : "s")"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        guard let date = modificationDate else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

enum FileType: String, CaseIterable {
    case markdown
    case json
    case pdf
    case text
    case binary
    case directory
    case unknown

    var icon: String {
        switch self {
        case .markdown: return "doc.richtext"
        case .json: return "curlybraces"
        case .pdf: return "doc.text.fill"
        case .text: return "doc.text"
        case .binary: return "doc.zipper"
        case .directory: return "folder.fill"
        case .unknown: return "doc"
        }
    }

    var extensions: [String] {
        switch self {
        case .markdown: return ["md", "markdown"]
        case .json: return ["json"]
        case .pdf: return ["pdf"]
        case .text: return ["txt", "log", "conf", "config"]
        case .binary: return ["db", "db-wal", "db-shm", "sqlite", "sqlite-wal", "sqlite-shm",
                              "dylib", "so", "a", "o", "zip", "gz", "tar", "bz2", "xz", "zst",
                              "png", "jpg", "jpeg", "gif", "bmp", "tiff", "ico", "webp",
                              "mp3", "mp4", "mov", "avi", "wav", "aac", "plist"]
        case .directory: return []
        case .unknown: return []
        }
    }

    var color: Color {
        switch self {
        case .markdown: return .blue
        case .json: return .orange
        case .pdf: return .red
        case .text: return .gray
        case .binary: return .purple
        case .directory: return .blue
        case .unknown: return .secondary
        }
    }

    static func detect(from url: URL) -> FileType {
        // Check if directory first
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return .directory
        }

        let ext = url.pathExtension.lowercased()

        // Check binary extensions
        if FileType.binary.extensions.contains(ext) {
            return .binary
        }

        // Check known extensions (markdown, json, pdf, text)
        for type in FileType.allCases where type != .unknown && type != .binary && type != .directory {
            if type.extensions.contains(ext) {
                return type
            }
        }

        // Content sniff: read first 1024 bytes
        if let handle = try? FileHandle(forReadingFrom: url) {
            let data = handle.readData(ofLength: 1024)
            handle.closeFile()

            // Check for null bytes → binary
            if data.contains(0) {
                return .binary
            }

            // Valid UTF-8 → text
            if String(data: data, encoding: .utf8) != nil {
                return .text
            }

            return .binary
        }

        return .unknown
    }
}
