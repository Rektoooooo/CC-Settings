import XCTest

final class HUDConfigFileTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("cc-hud-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private var encoded: Data {
        let encoder = JSONEncoder()
        return try! encoder.encode(HUDConfig())
    }

    func testMalformedConfigIsNotOverwritten() throws {
        let url = dir.appendingPathComponent("config.json")
        let broken = "{ \"display\": { \"showTools\": tru"
        try broken.write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try HUDConfigFile.save(encodedConfig: encoded, to: url))
        XCTAssertThrowsError(try HUDConfigFile.readExisting(at: url))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), broken)
    }

    func testUnknownNestedAndTopLevelKeysSurvive() throws {
        let url = dir.appendingPathComponent("config.json")
        try #"{"pluginKey":{"a":1},"display":{"showTools":true,"futureFlag":"x"},"colors":{"extra":"blue"},"gitStatus":{"newOpt":5}}"#
            .write(to: url, atomically: true, encoding: .utf8)
        try HUDConfigFile.save(encodedConfig: encoded, to: url)

        let json = try HUDConfigFile.readExisting(at: url)
        XCTAssertNotNil(json["pluginKey"])
        XCTAssertEqual((json["display"] as? [String: Any])?["futureFlag"] as? String, "x")
        XCTAssertEqual((json["colors"] as? [String: Any])?["extra"] as? String, "blue")
        XCTAssertEqual((json["gitStatus"] as? [String: Any])?["newOpt"] as? Int, 5)
        XCTAssertEqual((json["display"] as? [String: Any])?["showTools"] as? Bool, false)
    }

    func testMissingFileIsCreatedAndEmptyOverridesAreStripped() throws {
        let url = dir.appendingPathComponent("sub/config.json")
        try HUDConfigFile.save(encodedConfig: encoded, to: url)
        let display = try XCTUnwrap(HUDConfigFile.readExisting(at: url)["display"] as? [String: Any])
        XCTAssertNil(display["modelOverride"])
        XCTAssertNil(display["customLine"])
    }

    // MARK: - Edit-only saves (Phase 2)

    func testEditOnlySaveWritesOnlyChangedPathsAndKeepsExternalSiblingEdits() throws {
        let url = dir.appendingPathComponent("config.json")
        try #"{"language":"en","display":{"showTools":false,"showCost":false},"pluginKey":1}"#
            .write(to: url, atomically: true, encoding: .utf8)
        let baseline: [String: Any] = ["language": "en", "display": ["showTools": false, "showCost": false]]

        // Someone else changes showCost on disk after the screen loaded.
        try #"{"language":"en","display":{"showTools":false,"showCost":true},"pluginKey":1}"#
            .write(to: url, atomically: true, encoding: .utf8)

        // The user flips only showTools in the app (its in-memory showCost is still false).
        let edited: [String: Any] = ["language": "en", "display": ["showTools": true, "showCost": false]]
        let edits = HUDConfigFile.diff(from: baseline, to: edited)
        XCTAssertEqual(edits.count, 1)
        XCTAssertEqual(edits.first?.path, ["display", "showTools"])
        try HUDConfigFile.saveEdits(edits, to: url)

        let json = try HUDConfigFile.readExisting(at: url)
        let display = try XCTUnwrap(json["display"] as? [String: Any])
        XCTAssertEqual(display["showTools"] as? Bool, true)
        XCTAssertEqual(display["showCost"] as? Bool, true, "externally changed sibling must survive")
        XCTAssertEqual(json["pluginKey"] as? Int, 1)
    }

    func testEditOnlySaveRemovesDeletedCustomColorAndNothingElse() throws {
        let url = dir.appendingPathComponent("config.json")
        try ##"{"customColors":{"a":"#111111","b":"#222222"},"other":{"x":1}}"##
            .write(to: url, atomically: true, encoding: .utf8)
        let edits = HUDConfigFile.diff(
            from: ["customColors": ["a": "#111111", "b": "#222222"]],
            to: ["customColors": ["a": "#111111"]])
        try HUDConfigFile.saveEdits(edits, to: url)
        let json = try HUDConfigFile.readExisting(at: url)
        XCTAssertEqual((json["customColors"] as? [String: Any])?.keys.sorted(), ["a"])
        XCTAssertNotNil(json["other"])
    }

    func testNoChangesProducesNoEdits() {
        let config: [String: Any] = ["display": ["showTools": true], "elementOrder": ["a", "b"]]
        XCTAssertTrue(HUDConfigFile.diff(from: config, to: config).isEmpty)
    }
}
