import XCTest
@testable import CC_Settings

/// Phase 5 safety tests. Everything runs inside a throwaway home directory —
/// never the real ~/.claude or ~/.claude.json.
@MainActor
final class Phase5SafetyTests: XCTestCase {

    private var home: URL!
    private var fm: FileManager { .default }

    override func setUpWithError() throws {
        home = fm.temporaryDirectory.appendingPathComponent("cc-p5-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: home.appendingPathComponent(".claude/projects"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: home)
    }

    private func makeProjectFolder(for path: String, jsonl: String? = nil) throws -> URL {
        let dir = home.appendingPathComponent(".claude/projects/\(ProjectPathResolver.encode(path))")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        if let jsonl {
            try jsonl.write(to: dir.appendingPathComponent("s1.jsonl"), atomically: true, encoding: .utf8)
        }
        return dir
    }

    private func writeClaudeJSON(projectKeys: [String]) throws {
        let projects = Dictionary(uniqueKeysWithValues: projectKeys.map { ($0, [String: Any]()) })
        let data = try JSONSerialization.data(withJSONObject: ["projects": projects])
        try data.write(to: home.appendingPathComponent(".claude.json"))
    }

    // MARK: - Project path resolution

    func testEncodeMatchesClaudeCodeRule() {
        XCTAssertEqual(ProjectPathResolver.encode("/Users/a/.b c_d"), "-Users-a--b-c-d")
        XCTAssertEqual(ProjectPathResolver.encode("/x/me@host+1"), "-x-me-host-1")
        XCTAssertEqual(ProjectPathResolver.encode("/x/Příliš"), "-x-P--li-")
    }

    func testResolvesTrickyPathsViaClaudeJSONProjectsKeys() throws {
        let paths = [
            "/Users/test/.dotfiles/my-app",
            "/Users/test/work@home/proj+x",
            "/Users/test/Příliš žluťoučký/kůň",
            "/Users/test/My Project/sub_dir",
        ]
        for p in paths { _ = try makeProjectFolder(for: p) }
        try writeClaudeJSON(projectKeys: paths)

        let manager = ConfigurationManager(homeDirectory: home)
        let resolved = Set(manager.loadProjects().map(\.originalPath))
        XCTAssertEqual(resolved, Set(paths))
    }

    func testResolvesViaSessionCwdWhenNotInClaudeJSON() throws {
        let path = "/Users/test/Zahrada @ léto/app"
        let line = #"{"type":"user","cwd":"\#(path)","message":"hi"}"# + "\n"
        _ = try makeProjectFolder(for: path, jsonl: "{\"type\":\"summary\"}\n" + line)

        let manager = ConfigurationManager(homeDirectory: home)
        let project = try XCTUnwrap(manager.loadProjects().first)
        XCTAssertEqual(project.originalPath, path)
        XCTAssertTrue(project.isPathResolved)
    }

    func testCwdThatDoesNotEncodeBackToFolderIsRejected() throws {
        let line = #"{"cwd":"/some/other/place"}"# + "\n"
        _ = try makeProjectFolder(for: "/Users/test/real", jsonl: line)
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertFalse(try XCTUnwrap(manager.loadProjects().first).isPathResolved)
    }

    func testUnresolvedProjectIsInertAndNeverGuessed() throws {
        let dir = try makeProjectFolder(for: "/Users/test/gone-away")
        let manager = ConfigurationManager(homeDirectory: home)
        let project = try XCTUnwrap(manager.loadProjects().first)
        XCTAssertFalse(project.isPathResolved)
        XCTAssertTrue(project.originalPath.hasPrefix("/dev/null/"))
        XCTAssertThrowsError(try fm.createDirectory(
            at: URL(fileURLWithPath: project.originalPath).appendingPathComponent(".claude"),
            withIntermediateDirectories: true))

        XCTAssertFalse(manager.saveProjectClaudeMD("x", projectId: dir.lastPathComponent))
        XCTAssertNotNil(manager.lastError)
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("CLAUDE.md").path),
                       "must not fall back to ~/.claude/projects/<id>/CLAUDE.md")
    }

    func testProjectClaudeMDPrefersExistingNestedFileOverCreatingSecond() throws {
        let root = home.appendingPathComponent("proj", isDirectory: true)
        try fm.createDirectory(at: root.appendingPathComponent(".claude"), withIntermediateDirectories: true)
        try "nested".write(to: root.appendingPathComponent(".claude/CLAUDE.md"), atomically: true, encoding: .utf8)
        _ = try makeProjectFolder(for: root.path)
        try writeClaudeJSON(projectKeys: [root.path])

        let manager = ConfigurationManager(homeDirectory: home)
        let id = ProjectPathResolver.encode(root.path)
        XCTAssertEqual(manager.loadProjectClaudeMD(projectId: id), "nested")
        XCTAssertTrue(manager.saveProjectClaudeMD("edited", projectId: id))
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent(".claude/CLAUDE.md"), encoding: .utf8), "edited")
        XCTAssertFalse(fm.fileExists(atPath: root.appendingPathComponent("CLAUDE.md").path))
    }

    // MARK: - Symlink-preserving write

    func testAtomicWriteKeepsSymlinkAndPermissions() throws {
        let target = home.appendingPathComponent("dotfiles-CLAUDE.md")
        try "old".write(to: target, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
        let link = home.appendingPathComponent("link.md")
        try fm.createSymbolicLink(at: link, withDestinationURL: target)

        try "new".writeAtomicallyFollowingSymlinks(to: link)

        XCTAssertNotNil(try? fm.destinationOfSymbolicLink(atPath: link.path), "link must remain a symlink")
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "new")
        let perms = try fm.attributesOfItem(atPath: target.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(perms?.intValue, 0o600)
    }

    // MARK: - Editor conflict detection

    func testEditGuardDetectsExternalChangeAndOverwriteForces() throws {
        let file = home.appendingPathComponent("a.txt")
        try "v1".write(to: file, atomically: true, encoding: .utf8)
        var guardState = FileEditGuard()
        guardState.markLoaded(file)

        try "cli".write(to: file, atomically: true, encoding: .utf8)
        try fm.setAttributes([.modificationDate: Date().addingTimeInterval(10)], ofItemAtPath: file.path)

        XCTAssertFalse(guardState.save("mine", to: file))
        XCTAssertTrue(guardState.conflict)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "cli")

        XCTAssertTrue(guardState.save("mine", to: file, force: true))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "mine")
        XCTAssertFalse(guardState.conflict)
    }

    // MARK: - .gitignore

    func testGitignoreIsAppendedNotOverwritten() throws {
        let existing = "my-custom-rule\n.env\n"
        let merged = try XCTUnwrap(GitService.gitignoreContent(merging: existing))
        XCTAssertTrue(merged.hasPrefix(existing))
        XCTAssertTrue(merged.contains(GitService.gitignoreSectionMarker))
        XCTAssertTrue(merged.contains("history.jsonl"))
        XCTAssertTrue(merged.contains(".credentials.json"))
        XCTAssertEqual(merged.components(separatedBy: "\n.env\n").count, 2, ".env must not be duplicated")

        XCTAssertNil(GitService.gitignoreContent(merging: GitService.defaultGitignoreContent))
        XCTAssertEqual(GitService.gitignoreContent(merging: nil), GitService.defaultGitignoreContent)
    }

    // MARK: - Cleanup selection

    func testCleanupSelectsOnlySessionDataNeverMemory() throws {
        let dir = home.appendingPathComponent(".claude/projects/-p")
        let sessionID = UUID().uuidString
        try fm.createDirectory(at: dir.appendingPathComponent("memory"), withIntermediateDirectories: true)
        try fm.createDirectory(at: dir.appendingPathComponent("\(sessionID)/subagents"), withIntermediateDirectories: true)
        try "m".write(to: dir.appendingPathComponent("memory/MEMORY.md"), atomically: true, encoding: .utf8)
        try "{}".write(to: dir.appendingPathComponent("\(sessionID).jsonl"), atomically: true, encoding: .utf8)
        try "{}".write(to: dir.appendingPathComponent("custom-title.json"), atomically: true, encoding: .utf8)
        try "t".write(to: dir.appendingPathComponent("\(sessionID)/subagents/a.jsonl"), atomically: true, encoding: .utf8)

        let names = Set(SessionCleanup.sessionItems(in: dir).map(\.lastPathComponent))
        XCTAssertEqual(names, ["\(sessionID).jsonl", sessionID])
        XCTAssertFalse(names.contains("memory"))
        XCTAssertGreaterThan(SessionCleanup.size(of: SessionCleanup.sessionItems(in: dir)), 0)
    }

    // MARK: - OAuth token URL matching

    func testOAuthTokenMatchesOnNormalizedURLOnly() {
        let store: [String: Any] = [
            "github|abc": ["serverName": "github", "serverUrl": "https://api.github.example/mcp/", "accessToken": "SECRET"]
        ]
        // Same URL, different spelling => match.
        XCTAssertEqual(MCPDiscoveryService.token(in: store, forURL: "HTTPS://API.github.example:443/mcp"), "SECRET")
        // Repo server named "github" pointing elsewhere => no token.
        XCTAssertNil(MCPDiscoveryService.token(in: store, forURL: "https://evil.example/mcp"))
        XCTAssertNil(MCPDiscoveryService.token(in: store, forURL: "https://api.github.example/other"))
        XCTAssertNil(MCPDiscoveryService.token(in: store, forURL: nil))
    }
}
