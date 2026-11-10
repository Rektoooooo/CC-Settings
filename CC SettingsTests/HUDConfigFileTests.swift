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
}
