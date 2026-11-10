import Foundation

extension URL {
    /// The path a write should really target. Atomic writes replace the file at
    /// the given path, which would swap a symlink (e.g. a dotfiles-managed
    /// CLAUDE.md) for a regular file; writing to the resolved target keeps the link.
    func resolvingWriteTarget() -> URL {
        resolvingSymlinksInPath()
    }
}

extension Data {
    /// Atomic write that follows symlinks and keeps the existing file's POSIX permissions.
    func writeAtomicallyFollowingSymlinks(to url: URL) throws {
        let target = url.resolvingWriteTarget()
        let fm = FileManager.default
        let permissions = (try? fm.attributesOfItem(atPath: target.path))?[.posixPermissions]
        try write(to: target, options: .atomic)
        if let permissions {
            try? fm.setAttributes([.posixPermissions: permissions], ofItemAtPath: target.path)
        }
    }
}

extension String {
    func writeAtomicallyFollowingSymlinks(to url: URL) throws {
        try Data(utf8).writeAtomicallyFollowingSymlinks(to: url)
    }
}
