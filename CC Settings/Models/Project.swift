import Foundation

struct Project: Identifiable, Hashable {
    let id: String
    let originalPath: String
    var claudeMD: String?
    var settings: ClaudeSettings?
    var sessions: [Session]
    var totalSize: Int64
    var lastAccessed: Date?

    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var displayName: String {
        (originalPath as NSString).lastPathComponent
    }
}

struct Session: Identifiable, Hashable {
    let id: UUID
    let filename: String
    let size: Int64
    let lastModified: Date
    var messageCount: Int?

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
