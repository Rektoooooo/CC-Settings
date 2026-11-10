import XCTest
@testable import CC_Settings

final class Phase6ProjectTests: XCTestCase {

    private var root: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent("cc-p6-proj-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    /// Stand-in for the Trash so tests never touch the real one.
    private var deleteForReal: (URL) throws -> Void { { [fm] in try fm.removeItem(at: $0) } }

    private func makeProjectDir(files: [String] = [], dirs: [String] = []) throws -> URL {
        let dir = root.appendingPathComponent("-Users-test-app", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in files { try Data("{}".utf8).write(to: dir.appendingPathComponent(name)) }
        for name in dirs { try fm.createDirectory(at: dir.appendingPathComponent(name), withIntermediateDirectories: true) }
        return dir
    }

    // MARK: - Unresolved display

    func testUnresolvedProjectNeverShowsSentinel() {
        let id = "-Users-test-gone"
        let project = Project(id: id, originalPath: ProjectPathResolver.unresolvedPath(for: id),
                              claudeMD: nil, settings: nil, sessions: [], totalSize: 0, lastAccessed: nil)
        XCTAssertFalse(project.isPathResolved)
        XCTAssertEqual(project.displayName, "Unresolved path")
        XCTAssertEqual(project.displayPath, id)
        XCTAssertFalse(project.displayPath.contains("/dev/null"))
        XCTAssertFalse(project.displayName.contains("/dev/null"))
    }

    func testResolvedProjectDisplaysRealPath() {
        let project = Project(id: "-Users-test-app", originalPath: "/Users/test/app",
                              claudeMD: nil, settings: nil, sessions: [], totalSize: 0, lastAccessed: nil)
        XCTAssertTrue(project.isPathResolved)
        XCTAssertEqual(project.displayName, "app")
        XCTAssertEqual(project.displayPath, "/Users/test/app")
    }

    func testDisplayHelpersHandleSentinelDirectly() {
        let sentinel = ProjectPathResolver.unresolvedPath(for: "x-y")
        XCTAssertEqual(ProjectPathResolver.displayPath(sentinel, id: "x-y"), "x-y")
        XCTAssertEqual(ProjectPathResolver.displayName(path: sentinel, id: "x-y"), ProjectPathResolver.unresolvedLabel)
        XCTAssertFalse(ProjectPathResolver.unresolvedExplanation.isEmpty)
    }

    // MARK: - Cleanup removes an emptied project folder, never a non-empty one

    func testEmptiedProjectFolderIsRemoved() throws {
        let dir = try makeProjectDir(files: ["a.jsonl", "b.jsonl"], dirs: [UUID().uuidString])
        let failures = SessionCleanup.trashSessions(in: dir, trash: deleteForReal)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertFalse(fm.fileExists(atPath: dir.path), "folder left completely empty is removed too")
    }

    func testFolderWithMemoryIsKept() throws {
        let dir = try makeProjectDir(files: ["a.jsonl"], dirs: ["memory"])
        try Data("note".utf8).write(to: dir.appendingPathComponent("memory/MEMORY.md"))
        let failures = SessionCleanup.trashSessions(in: dir, trash: deleteForReal)
        XCTAssertTrue(failures.isEmpty)
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("memory/MEMORY.md").path))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("a.jsonl").path))
    }

    func testFolderWithCustomTitleIsKept() throws {
        let dir = try makeProjectDir(files: ["a.jsonl", "custom-title.json"])
        _ = SessionCleanup.trashSessions(in: dir, trash: deleteForReal)
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("custom-title.json").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.path))
    }

    func testHiddenFileCountsAsContent() throws {
        let dir = try makeProjectDir(files: ["a.jsonl", ".DS_Store"])
        _ = SessionCleanup.trashSessions(in: dir, trash: deleteForReal)
        XCTAssertTrue(fm.fileExists(atPath: dir.path))
    }

    func testFolderIsNotRemovedAfterAFailure() throws {
        let dir = try makeProjectDir(files: ["a.jsonl", "b.jsonl"])
        struct Boom: Error {}
        var calls = 0
        let failures = SessionCleanup.trashSessions(in: dir, trash: { url in
            calls += 1
            if url.lastPathComponent == "a.jsonl" { throw Boom() }
            try FileManager.default.removeItem(at: url)
        })
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(calls, 2, "no attempt to trash the folder after a failure")
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("a.jsonl").path))
    }

    func testAlreadyEmptyFolderHelper() throws {
        let dir = try makeProjectDir()
        XCTAssertTrue(try SessionCleanup.trashFolderIfEmpty(dir, trash: deleteForReal))
        XCTAssertFalse(fm.fileExists(atPath: dir.path))
        let missing = root.appendingPathComponent("nope")
        XCTAssertFalse(try SessionCleanup.trashFolderIfEmpty(missing, trash: deleteForReal))
    }
}
