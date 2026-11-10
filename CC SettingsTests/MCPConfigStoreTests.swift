import XCTest

/// All tests run against a temp directory. They must never touch the real ~/.claude.json.
final class MCPConfigStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("cc-mcp-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ name: String, _ text: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func json(_ url: URL) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }

    // MARK: - Malformed file

    func testMalformedFileIsNeverOverwritten() throws {
        let broken = "{ \"oauthAccount\": { \"x\": 1 ,, \"mcpServers\": "
        let url = try write(".claude.json", broken)
        let store = MCPConfigStore(fileURL: url)

        XCTAssertThrowsError(try store.save(["a": MCPServerConfig(id: "a", command: "x")]))
        XCTAssertThrowsError(try store.upsert(["a": ["command": "x"]]))
        XCTAssertThrowsError(try store.remove(["a"]))
        XCTAssertThrowsError(try store.loadServers())
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), broken)
    }

    func testMissingFileIsCreatedAndEmptyReadsAsNoServers() throws {
        let url = dir.appendingPathComponent("new.json")
        let store = MCPConfigStore(fileURL: url)
        XCTAssertEqual(try store.loadServers().count, 0)
        try store.save(["a": MCPServerConfig(id: "a", command: "x")])
        XCTAssertNotNil(try json(url)["mcpServers"])
    }

    func testOtherTopLevelKeysSurviveSave() throws {
        let url = try write(".claude.json", #"{"oauthAccount":{"email":"a@b.c"},"numStartups":7,"mcpServers":{}}"#)
        try MCPConfigStore(fileURL: url).save(["a": MCPServerConfig(id: "a", command: "x")])
        let root = try json(url)
        XCTAssertEqual((root["oauthAccount"] as? [String: Any])?["email"] as? String, "a@b.c")
        XCTAssertEqual(root["numStartups"] as? Int, 7)
    }

    // MARK: - Headers

    func testHeadersSurviveAnEditThatCarriesThem() throws {
        let url = try write(".claude.json", """
        {"mcpServers":{"api":{"type":"http","url":"https://x/mcp","headers":{"Authorization":"Bearer t"},"timeout":5000}}}
        """)
        let store = MCPConfigStore(fileURL: url)
        var servers = try store.loadServers()
        servers["api"]?.url = "https://y/mcp"
        try store.save(servers)

        let api = (try json(url)["mcpServers"] as! [String: Any])["api"] as! [String: Any]
        XCTAssertEqual(api["url"] as? String, "https://y/mcp")
        XCTAssertEqual((api["headers"] as? [String: String])?["Authorization"], "Bearer t")
        XCTAssertEqual(api["timeout"] as? Int, 5000)
    }

    func testClearingHeadersRemovesThem() throws {
        let url = try write(".claude.json", #"{"mcpServers":{"api":{"type":"http","url":"https://x","headers":{"A":"b"}}}}"#)
        let store = MCPConfigStore(fileURL: url)
        var servers = try store.loadServers()
        servers["api"]?.headers = nil
        try store.save(servers)
        let api = (try json(url)["mcpServers"] as! [String: Any])["api"] as! [String: Any]
        XCTAssertNil(api["headers"])
    }

    // MARK: - .mcp.json unknown per-server keys

    func testProjectFileKeepsUnknownKeysOfOtherServers() throws {
        let url = try write(".mcp.json", """
        {"mcpServers":{
          "one":{"type":"http","url":"https://one","oauth":{"clientId":"abc"},"headersHelper":"/bin/h"},
          "two":{"command":"node","args":["a"],"timeout":9}
        }}
        """)
        let store = MCPConfigStore(fileURL: url, deleteFileWhenEmpty: true)
        var servers = try store.loadServers()
        servers["two"]?.args = ["b"]
        try store.save(servers)

        let map = try json(url)["mcpServers"] as! [String: [String: Any]]
        XCTAssertEqual((map["one"]?["oauth"] as? [String: String])?["clientId"], "abc")
        XCTAssertEqual(map["one"]?["headersHelper"] as? String, "/bin/h")
        XCTAssertEqual(map["two"]?["timeout"] as? Int, 9)
        XCTAssertEqual(map["two"]?["args"] as? [String], ["b"])
    }

    func testProjectFileDeletedWhenLastServerRemoved() throws {
        let url = try write(".mcp.json", #"{"mcpServers":{"one":{"command":"x"}}}"#)
        try MCPConfigStore(fileURL: url, deleteFileWhenEmpty: true).remove(["one"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - Rename / move

    func testRenameKeepsUnknownKeys() throws {
        let url = try write(".claude.json", #"{"keep":1,"mcpServers":{"old":{"command":"x","oauth":{"t":"secret"},"timeout":3}}}"#)
        let store = MCPConfigStore(fileURL: url)
        var edited = try store.loadServers()["old"]!
        edited.id = "new"
        edited.args = ["--flag"]
        try MCPConfigStore.transfer(name: "old", from: store, to: store, as: "new", edited: edited)

        let root = try json(url)
        let map = root["mcpServers"] as! [String: [String: Any]]
        XCTAssertNil(map["old"])
        XCTAssertEqual((map["new"]?["oauth"] as? [String: String])?["t"], "secret")
        XCTAssertEqual(map["new"]?["timeout"] as? Int, 3)
        XCTAssertEqual(map["new"]?["args"] as? [String], ["--flag"])
        XCTAssertEqual(root["keep"] as? Int, 1)
    }

    func testMoveCopiesRawDictAndWritesTargetBeforeRemovingSource() throws {
        let userURL = try write(".claude.json", #"{"mcpServers":{"s":{"type":"sse","url":"https://s","oauth":{"a":1},"headers":{"H":"v"}}}}"#)
        let projURL = dir.appendingPathComponent("proj/.mcp.json")
        let source = MCPConfigStore(fileURL: userURL)
        let target = MCPConfigStore(fileURL: projURL, deleteFileWhenEmpty: true)
        try MCPConfigStore.transfer(name: "s", from: source, to: target)

        let moved = (try json(projURL)["mcpServers"] as! [String: [String: Any]])["s"]!
        XCTAssertNotNil(moved["oauth"])
        XCTAssertNotNil(moved["headers"])
        XCTAssertEqual(((try json(userURL)["mcpServers"]) as! [String: Any]).count, 0)
    }

    func testFailedTargetLeavesSourceUntouched() throws {
        let sourceText = #"{"mcpServers":{"s":{"command":"x"}}}"#
        let userURL = try write(".claude.json", sourceText)
        let badTarget = try write("bad.json", "{ not json")
        XCTAssertThrowsError(try MCPConfigStore.transfer(
            name: "s", from: MCPConfigStore(fileURL: userURL), to: MCPConfigStore(fileURL: badTarget)))
        XCTAssertEqual(try String(contentsOf: userURL, encoding: .utf8), sourceText)
    }

    func testLocalScopeWritesOnlyThatProject() throws {
        let url = try write(".claude.json", #"{"projects":{"/a":{"history":[1],"mcpServers":{"x":{"command":"c","oauth":{"k":1}}}},"/b":{"trust":true}}}"#)
        let store = MCPConfigStore(fileURL: url, projectKey: "/a")
        var servers = try store.loadServers()
        servers["x"]?.command = "d"
        try store.save(servers)
        let projects = try json(url)["projects"] as! [String: [String: Any]]
        XCTAssertEqual(projects["/b"]?["trust"] as? Bool, true)
        XCTAssertNotNil(projects["/a"]?["history"])
        let x = (projects["/a"]?["mcpServers"] as! [String: [String: Any]])["x"]!
        XCTAssertEqual(x["command"] as? String, "d")
        XCTAssertNotNil(x["oauth"])
    }

    // MARK: - Unknown transport types

    func testUnknownTypeRoundTripsAndIsFlaggedUnsupported() throws {
        let url = try write(".claude.json", #"{"mcpServers":{"w":{"type":"ws","url":"wss://x","custom":{"a":[1,2]}},"o":{"command":"x"}}}"#)
        let store = MCPConfigStore(fileURL: url)
        var servers = try store.loadServers()
        XCTAssertTrue(servers["w"]!.hasUnsupportedType)
        XCTAssertFalse(servers["o"]!.hasUnsupportedType)
        servers["o"]?.args = ["z"]
        try store.save(servers)

        let w = (try json(url)["mcpServers"] as! [String: [String: Any]])["w"]!
        XCTAssertEqual(w["type"] as? String, "ws")
        XCTAssertEqual(w["url"] as? String, "wss://x")
        XCTAssertNotNil(w["custom"])
    }

    // MARK: - Integer formatting

    func testRestoreIntegersLeavesStringsAlone() {
        let text = #"{"a": 10000.0, "b": "version: 1.0, next", "c": [2.0, 3.50], "d": 1.05}"#
        let out = String(data: JSONTextFixer.restoreIntegers(Data(text.utf8)), encoding: .utf8)!
        XCTAssertEqual(out, #"{"a": 10000, "b": "version: 1.0, next", "c": [2, 3.50], "d": 1.05}"#)
    }
}
