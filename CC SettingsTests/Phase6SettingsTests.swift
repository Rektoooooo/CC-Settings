import XCTest
@testable import CC_Settings

/// Phase 6: settings keys added for Claude Code 2.1.322. Throwaway home directory only.
@MainActor
final class Phase6SettingsTests: XCTestCase {

    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-phase6-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".claude"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private var settingsPath: URL { home.appendingPathComponent(".claude/settings.json") }

    private func write(_ json: String) throws {
        try Data(json.utf8).write(to: settingsPath)
    }

    private func readJSON() throws -> [String: Any] {
        let data = try Data(contentsOf: settingsPath)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Default-on flags: off writes false, on removes the key

    func testDefaultOnFlagsWriteFalseAndRemoveKey() throws {
        try write(#"{"model":"opus","futureKey":{"a":1}}"#)
        let manager = ConfigurationManager(homeDirectory: home)

        for key in ["idleCompaction", "switchModelsOnFlag", "syncClaudeAiSkills", "syncClaudeAiPlugins"] {
            manager.saveDefaultOnFlag(key, enabled: false)
            XCTAssertEqual(try readJSON()[key] as? Bool, false, key)
            manager.saveDefaultOnFlag(key, enabled: true)
            XCTAssertNil(try readJSON()[key], "\(key) on == CLI default, key removed")
        }
        let json = try readJSON()
        XCTAssertEqual(json["model"] as? String, "opus")
        XCTAssertNotNil(json["futureKey"])
    }

    func testDecodeOfNewKeys() throws {
        try write(#"{"idleCompaction":false,"maxProseWidth":80,"bashEditDiffEnabled":true,"switchModelsOnFlag":false,"syncClaudeAiSkills":false,"syncClaudeAiPlugins":false,"attributionProject":"claude_proj_abc"}"#)
        let s = ConfigurationManager(homeDirectory: home).settings
        XCTAssertEqual(s.idleCompaction, false)
        XCTAssertEqual(s.maxProseWidth, 80)
        XCTAssertEqual(s.bashEditDiffEnabled, true)
        XCTAssertEqual(s.switchModelsOnFlag, false)
        XCTAssertEqual(s.syncClaudeAiSkills, false)
        XCTAssertEqual(s.syncClaudeAiPlugins, false)
        XCTAssertEqual(s.attributionProject, "claude_proj_abc")
    }

    func testWrongTypesDoNotBreakDecode() throws {
        try write(#"{"idleCompaction":"yes","maxProseWidth":"wide","model":"opus"}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertNil(manager.settings.idleCompaction)
        XCTAssertNil(manager.settings.maxProseWidth)
        XCTAssertEqual(manager.settings.model, "opus")
    }

    // MARK: - Tri-state bashEditDiffEnabled

    func testBashEditDiffTriState() throws {
        try write(#"{}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        manager.saveTriStateFlag("bashEditDiffEnabled", value: true)
        XCTAssertEqual(try readJSON()["bashEditDiffEnabled"] as? Bool, true)
        manager.saveTriStateFlag("bashEditDiffEnabled", value: false)
        XCTAssertEqual(try readJSON()["bashEditDiffEnabled"] as? Bool, false)
        manager.saveTriStateFlag("bashEditDiffEnabled", value: nil)
        XCTAssertNil(try readJSON()["bashEditDiffEnabled"])
    }

    // MARK: - maxProseWidth

    func testMaxProseWidthValidation() throws {
        try write(#"{}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertTrue(manager.saveMaxProseWidth("100"))
        XCTAssertEqual(try readJSON()["maxProseWidth"] as? Int, 100)

        XCTAssertFalse(manager.saveMaxProseWidth("39"), "below the CLI minimum of 40")
        XCTAssertFalse(manager.saveMaxProseWidth("abc"))
        XCTAssertEqual(try readJSON()["maxProseWidth"] as? Int, 100, "invalid entries write nothing")

        XCTAssertTrue(manager.saveMaxProseWidth("40"))
        XCTAssertEqual(try readJSON()["maxProseWidth"] as? Int, 40)

        XCTAssertTrue(manager.saveMaxProseWidth("  "))
        XCTAssertNil(try readJSON()["maxProseWidth"])
    }

    // MARK: - attributionProject

    func testAttributionProjectIdValidation() {
        XCTAssertEqual(AttributionProjectID.normalized(" claude_proj_01ABC "), "claude_proj_01ABC")
        XCTAssertEqual(AttributionProjectID.normalized("chan_xyz"), "chan_xyz")
        let uuid = "123E4567-E89B-12D3-A456-426614174000"
        XCTAssertEqual(AttributionProjectID.normalized(uuid), uuid)
        XCTAssertNil(AttributionProjectID.normalized("claude_proj_"), "prefix alone")
        XCTAssertNil(AttributionProjectID.normalized("chan_"))
        XCTAssertNil(AttributionProjectID.normalized("proj_123"))
        XCTAssertNil(AttributionProjectID.normalized("claude_proj_a b"))
        XCTAssertNil(AttributionProjectID.normalized(""))
    }

    func testSaveAttributionProject() throws {
        try write(#"{"model":"opus"}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertTrue(manager.saveAttributionProject("claude_proj_123"))
        XCTAssertEqual(try readJSON()["attributionProject"] as? String, "claude_proj_123")

        XCTAssertFalse(manager.saveAttributionProject("nonsense"))
        XCTAssertEqual(try readJSON()["attributionProject"] as? String, "claude_proj_123", "invalid id writes nothing")

        XCTAssertTrue(manager.saveAttributionProject(""))
        XCTAssertNil(try readJSON()["attributionProject"])
        XCTAssertEqual(try readJSON()["model"] as? String, "opus")
    }

    // MARK: - permissions.* flags

    func testPermissionFlagsAreMergedAndRemoved() throws {
        try write(#"{"permissions":{"allow":["Bash(ls)"],"futureSub":1}}"#)
        let manager = ConfigurationManager(homeDirectory: home)

        manager.saveDefaultOffFlag(["permissions", "denyInsteadOfPrompting"], enabled: true)
        manager.saveDefaultOffFlag(["permissions", "blockReadsOutsideWorkingDirectories"], enabled: true)
        manager.saveDefaultOffFlag(["permissions", "blockWritesOutsideWorkingDirectories"], enabled: true)
        var perms = try XCTUnwrap(try readJSON()["permissions"] as? [String: Any])
        XCTAssertEqual(perms["denyInsteadOfPrompting"] as? Bool, true)
        XCTAssertEqual(perms["blockReadsOutsideWorkingDirectories"] as? Bool, true)
        XCTAssertEqual(perms["blockWritesOutsideWorkingDirectories"] as? Bool, true)
        XCTAssertEqual(perms["allow"] as? [String], ["Bash(ls)"])
        XCTAssertNotNil(perms["futureSub"])
        XCTAssertTrue(manager.permissionFlag("denyInsteadOfPrompting"))

        manager.saveDefaultOffFlag(["permissions", "denyInsteadOfPrompting"], enabled: false)
        perms = try XCTUnwrap(try readJSON()["permissions"] as? [String: Any])
        XCTAssertNil(perms["denyInsteadOfPrompting"], "default-off flag removes the key when off")
        XCTAssertFalse(manager.permissionFlag("denyInsteadOfPrompting"))
        XCTAssertEqual(perms["blockReadsOutsideWorkingDirectories"] as? Bool, true)
    }

    // MARK: - instructionFiles (plugin key is ONE path segment)

    func testInstructionFilesWritesPluginKeyAsSingleSegment() throws {
        try write(#"{"pluginConfigs":{"other@market":{"options":{"x":1}}},"model":"opus"}"#)
        let manager = ConfigurationManager(homeDirectory: home)

        manager.saveInstructionFiles(.claudeMdAndAgentsMd)
        let json = try readJSON()
        let configs = try XCTUnwrap(json["pluginConfigs"] as? [String: Any])
        let entry = try XCTUnwrap(configs["cc-plugin-agents-md@builtin"] as? [String: Any])
        XCTAssertEqual((entry["options"] as? [String: Any])?["instructionFiles"] as? String, "claude-md-and-agents-md")
        XCTAssertNotNil(configs["other@market"], "other plugin configs untouched")
        XCTAssertEqual(json["model"] as? String, "opus")
        XCTAssertEqual(manager.readInstructionFiles(), .claudeMdAndAgentsMd)

        // Default removes the key and prunes the emptied parents, leaving other plugins alone.
        manager.saveInstructionFiles(.default)
        let after = try XCTUnwrap(try readJSON()["pluginConfigs"] as? [String: Any])
        XCTAssertNil(after["cc-plugin-agents-md@builtin"])
        XCTAssertNotNil(after["other@market"])
        XCTAssertEqual(manager.readInstructionFiles(), .default)
    }

    func testInstructionFilesDefaultWithNoConfigsLeavesNoStubs() throws {
        try write(#"{"model":"opus"}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        manager.saveInstructionFiles(.default)
        XCTAssertNil(try readJSON()["pluginConfigs"])
    }

    func testInstructionFilesLegacyReadAndExplicitDefaultWhenLegacyPresent() throws {
        let raw: [String: Any] = ["pluginConfigs": ["cc-plugin-agents-md@builtin": ["options": ["projectInstructions": "both"]]]]
        XCTAssertEqual(ConfigurationManager.readInstructionFiles(in: raw), .claudeMdAndAgentsMd)
        let none: [String: Any] = ["pluginConfigs": ["agents-md@builtin": ["options": ["projectInstructions": "none"]]]]
        XCTAssertEqual(ConfigurationManager.readInstructionFiles(in: none), .managedOnly)
        let bogus: [String: Any] = ["pluginConfigs": ["cc-plugin-agents-md@builtin": ["options": ["instructionFiles": "weird"]]]]
        XCTAssertEqual(ConfigurationManager.readInstructionFiles(in: bogus), .default)

        try write(#"{"pluginConfigs":{"cc-plugin-agents-md@builtin":{"options":{"projectInstructions":"both"}}}}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        manager.saveInstructionFiles(.default)
        let options = (((try readJSON()["pluginConfigs"] as? [String: Any])?["cc-plugin-agents-md@builtin"]) as? [String: Any])?["options"] as? [String: Any]
        XCTAssertEqual(options?["instructionFiles"] as? String, "claude-md-or-agents-md",
                       "legacy key would otherwise apply again")
        XCTAssertEqual(options?["projectInstructions"] as? String, "both", "legacy key preserved")
    }

    // MARK: - Hook definition fields live in `extra` and round-trip

    func testHookOptionalFieldsRoundTrip() throws {
        let json = #"{"type":"command","command":"echo hi","timeout":5,"headers":{"a":"b"}}"#
        var def = try JSONDecoder().decode(HookDefinition.self, from: Data(json.utf8))
        XCTAssertNil(def.statusMessage)
        XCTAssertNil(def.once)

        def.statusMessage = "Linting"
        def.once = true
        def.runsAsync = true
        def.onFailure = "block"
        let data = try JSONEncoder().encode(def)
        let obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["statusMessage"] as? String, "Linting")
        XCTAssertEqual(obj["once"] as? Bool, true)
        XCTAssertEqual(obj["async"] as? Bool, true)
        XCTAssertEqual(obj["onFailure"] as? String, "block")
        XCTAssertEqual(obj["command"] as? String, "echo hi")
        XCTAssertNotNil(obj["headers"], "unmodeled keys survive")

        def.statusMessage = nil
        def.once = nil
        def.runsAsync = nil
        def.onFailure = nil
        let cleared = try XCTUnwrap(try JSONSerialization.jsonObject(with: JSONEncoder().encode(def)) as? [String: Any])
        for key in ["statusMessage", "once", "async", "onFailure"] { XCTAssertNil(cleared[key], key) }
    }
}
