import SwiftUI

struct GitRepository: Identifiable, Hashable, Sendable {
    let id: String            // path string as identifier
    let path: URL
    let displayName: String   // last path component
    let isClaudeProject: Bool // came from Claude Code projects list
}

struct GitCommit: Identifiable, Equatable, Sendable {
    let id: String
    let shortHash: String
    let message: String
    let author: String
    let date: Date
    let filesChanged: Int

    static func == (lhs: GitCommit, rhs: GitCommit) -> Bool {
        lhs.id == rhs.id
    }
}

struct GitFileChange: Identifiable, Hashable, Sendable {
    var id: String { path }
    let path: String
    let status: GitFileStatus
    let staged: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(path)
    }

    static func == (lhs: GitFileChange, rhs: GitFileChange) -> Bool {
        lhs.path == rhs.path && lhs.status == rhs.status && lhs.staged == rhs.staged
    }
}

enum GitFileStatus: String, CaseIterable, Sendable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case untracked = "?"

    var icon: String {
        switch self {
        case .modified: return "pencil.circle.fill"
        case .added: return "plus.circle.fill"
        case .deleted: return "minus.circle.fill"
        case .renamed: return "arrow.right.circle.fill"
        case .untracked: return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .renamed: return .themeAccent
        case .untracked: return .secondary
        }
    }

    var displayName: String {
        switch self {
        case .modified: return "Modified"
        case .added: return "Added"
        case .deleted: return "Deleted"
        case .renamed: return "Renamed"
        case .untracked: return "Untracked"
        }
    }
}
