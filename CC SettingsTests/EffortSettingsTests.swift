import XCTest

/// Effort / maxEffortLevel / custom-model write paths. Throwaway home only.
@MainActor
final class EffortSettingsTests: XCTestCase {

    private var home: URL!
    private var settingsPath: URL { home.appendingPathComponent(".claude/settings.json") }

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-effort-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".claude"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: home) }

    private func write(_ json: String) throws { try Data(json.utf8).write(to: settingsPath) }

    private func readJSON() throws -> [String: Any] {
        let data = try Data(contentsOf: settingsPath)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testEffortForNewModelWritesModelSettingsAndKeepsOtherKeys() throws {
        try write(#"{"model":"opus[1m]","futureKey":{"a":1},"modelSettings":{"claude-sonnet-5-5":{"effortLevel":"low","autoCompactWindow":"auto"}}}"#)
        let m = ConfigurationManager(homeDirectory: home)

        m.saveEffortLevel("xhigh", forModel: "opus[1m]")

        let json = try readJSON()
        let ms = try XCTUnwrap(json["modelSettings"] as? [String: Any])
        XCTAssertEqual((ms["claude-opus-5-5"] as? [String: Any])?["effortLevel"] as? String, "xhigh")
        XCTAssertEqual((ms["claude-sonnet-5-5"] as? [String: Any])?["autoCompactWindow"] as? String, "auto")
        XCTAssertNil(json["effortLevel"])
        XCTAssertNotNil(json["futureKey"])
    }

    func testClearingEffortRemovesEmptyModelSettings() throws {
        try write(#"{"modelSettings":{"claude-opus-5-5":{"effortLevel":"high"}}}"#)
        let m = ConfigurationManager(homeDirectory: home)
        m.saveEffortLevel(nil, forModel: "opus")
        XCTAssertNil(try readJSON()["modelSettings"])
    }

    func testAllowlistedModelsUseTopLevelOthersUseModelSettings() throws {
        try write("{}")
        let m = ConfigurationManager(homeDirectory: home)
        m.saveEffortLevel("high", forModel: "claude-opus-5")
        XCTAssertEqual(try readJSON()["effortLevel"] as? String, "high")
        // Dated id canonicalizes to the allowlisted claude-sonnet-4-5.
        m.saveEffortLevel("low", forModel: "claude-sonnet-4-5-20250929")
        XCTAssertEqual(try readJSON()["effortLevel"] as? String, "low")
        XCTAssertNil(try readJSON()["modelSettings"])
        // Custom / proxy ids are not parseable Claude ids: top-level applies.
        m.saveEffortLevel("medium", forModel: "my-proxy-model")
        XCTAssertEqual(try readJSON()["effortLevel"] as? String, "medium")
        XCTAssertNil(try readJSON()["modelSettings"])
        // A cleanly parsed Claude id outside the allowlist uses modelSettings.
        m.saveEffortLevel("xhigh", forModel: "claude-opus-6")
        let ms = try XCTUnwrap(try readJSON()["modelSettings"] as? [String: Any])
        XCTAssertEqual((ms["claude-opus-6"] as? [String: Any])?["effortLevel"] as? String, "xhigh")
        XCTAssertEqual(try readJSON()["effortLevel"] as? String, "medium")
    }

    func testUnsetModelWritesNothing() throws {
        try write(#"{"keep":1}"#)
        let m = ConfigurationManager(homeDirectory: home)
        m.saveEffortLevel("high", forModel: "")
        let json = try readJSON()
        XCTAssertNil(json["effortLevel"])
        XCTAssertNil(json["modelSettings"])
        XCTAssertNil(ConfigurationManager.readEffort(in: ["effortLevel": "high"], model: "").value)
    }

    func testReadEffortRules() {
        let raw: [String: Any] = [
            "effortLevel": "high",
            "modelSettings": ["claude-opus-5-5": ["effortLevel": "xhigh"]],
        ]
        XCTAssertEqual(ConfigurationManager.readEffort(in: raw, model: "opus").value, "xhigh")
        // 5.5 model without a per-model value: the top-level fallback does not apply.
        XCTAssertNil(ConfigurationManager.readEffort(in: raw, model: "sonnet").value)
        // Legacy model: falls back to top-level.
        XCTAssertEqual(ConfigurationManager.readEffort(in: raw, model: "claude-opus-5").value, "high")
    }

    func testInvalidTopLevelEffortIsFlaggedAndClearable() throws {
        try write(#"{"effortLevel":"ultracode","keep":1}"#)
        let m = ConfigurationManager(homeDirectory: home)
        XCTAssertEqual(m.readEffort(forModel: "claude-opus-5").invalidTopLevel, "ultracode")
        XCTAssertNil(m.readEffort(forModel: "claude-opus-5").value)
        m.clearTopLevelEffort()
        let json = try readJSON()
        XCTAssertNil(json["effortLevel"])
        XCTAssertEqual(json["keep"] as? Int, 1)
    }

    func testMaxEffortLevelSetAndClear() throws {
        try write(#"{"model":"opus"}"#)
        let m = ConfigurationManager(homeDirectory: home)
        m.saveMaxEffortLevel("max")
        XCTAssertEqual(try readJSON()["maxEffortLevel"] as? String, "max")
        m.saveMaxEffortLevel(nil)
        let json = try readJSON()
        XCTAssertNil(json["maxEffortLevel"])
        XCTAssertEqual(json["model"] as? String, "opus")
    }

    func testCustomModelDetectionNeverUsesSubstringAndNoPlaceholder() {
        XCTAssertTrue(HierarchicalModelPicker.isCustomValue("my-opus-proxy"))
        XCTAssertTrue(HierarchicalModelPicker.isCustomValue("opu"))
        XCTAssertFalse(HierarchicalModelPicker.isCustomValue("opus"))
        XCTAssertFalse(HierarchicalModelPicker.isCustomValue(""))
        XCTAssertNil(findModel(byModelId: "__custom__"))
    }
}
