import XCTest

/// Phase 2: every control must write the key and value Claude Code actually reads.
/// All tests use a throwaway home directory, never the real ~/.claude.
@MainActor
final class Phase2SettingsTests: XCTestCase {

    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-phase2-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".claude"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private var settingsPath: URL { home.appendingPathComponent(".claude/settings.json") }

    private func write(_ json: String, to url: URL? = nil) throws {
        try Data(json.utf8).write(to: url ?? settingsPath)
    }

    private func readJSON(_ url: URL? = nil) throws -> [String: Any] {
        let data = try Data(contentsOf: url ?? settingsPath)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Thinking

    func testThinkingOffWritesFalseAndOnRemovesKey() throws {
        try write(#"{"model":"opus","futureKey":{"a":1}}"#)
        let manager = ConfigurationManager(homeDirectory: home)

        manager.saveThinkingEnabled(false)
        XCTAssertEqual(try readJSON()["alwaysThinkingEnabled"] as? Bool, false)
        XCTAssertEqual(manager.settings.alwaysThinkingEnabled, false)

        manager.saveThinkingEnabled(true)
        let json = try readJSON()
        XCTAssertNil(json["alwaysThinkingEnabled"], "absent means on in Claude Code")
        XCTAssertEqual(json["model"] as? String, "opus")
        XCTAssertNotNil(json["futureKey"])
    }

    func testAbsentThinkingKeyReadsAsNil() throws {
        try write(#"{}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertNil(manager.settings.alwaysThinkingEnabled)
        XCTAssertTrue(manager.settings.alwaysThinkingEnabled ?? true)
    }

    // MARK: - skipDangerousModePermissionPrompt

    func testSkipDangerousPromptIsTopLevelAndStrayCopyIsRetired() throws {
        try write(#"{"permissions":{"allow":["Bash"],"skipDangerousModePermissionPrompt":true}}"#)
        let manager = ConfigurationManager(homeDirectory: home)

        manager.saveSkipDangerousModePrompt(true)

        let json = try readJSON()
        XCTAssertEqual(json["skipDangerousModePermissionPrompt"] as? Bool, true)
        let perms = try XCTUnwrap(json["permissions"] as? [String: Any])
        XCTAssertNil(perms["skipDangerousModePermissionPrompt"])
        XCTAssertEqual(perms["allow"] as? [String], ["Bash"])
        XCTAssertEqual(manager.settings.skipDangerousModePermissionPrompt, true)

        manager.saveSkipDangerousModePrompt(false)
        XCTAssertNil(try readJSON()["skipDangerousModePermissionPrompt"])
    }

    // MARK: - permissions.defaultMode

    func testDefaultModeValuesRoundTrip() throws {
        for mode in ["acceptEdits", "auto", "bypassPermissions", "default", "dontAsk", "plan"] {
            XCTAssertEqual(DefaultPermissionMode.parse(mode)?.rawValue, mode, mode)
            try write(#"{"permissions":{"defaultMode":"\#(mode)"}}"#)
            let manager = ConfigurationManager(homeDirectory: home)
            XCTAssertEqual(manager.settings.permissions.defaultMode, mode)
            manager.saveField("permissions.defaultMode", value: mode)
            XCTAssertEqual((try readJSON()["permissions"] as? [String: Any])?["defaultMode"] as? String, mode)
        }
        XCTAssertEqual(DefaultPermissionMode.parse("manual"), .defaultMode, "manual is an alias for default")
        XCTAssertNil(DefaultPermissionMode.parse("allowAll"), "the old fake values are not valid modes")
    }

    // MARK: - Sandbox key mapping

    func testSandboxFlatKeysMapToNestedPaths() throws {
        try write(#"{"sandbox":{"enabled":true,"ignoreViolations":{"*":["/tmp"]},"network":{"httpProxyPort":8080}}}"#)
        let manager = ConfigurationManager(homeDirectory: home)

        manager.saveFields(ExperimentalFeaturesView.sandboxKeyMapping(
            enableWeakerNestedSandbox: true,
            excludedCommands: ["git", "docker"],
            allowLocalBinding: true,
            allowAllUnixSockets: false,
            allowedDomains: ["*.github.com"]
        ))

        let json = try readJSON()
        XCTAssertNil(json["enableWeakerSandbox"])
        XCTAssertNil(json["allowedDomains"])
        let sandbox = try XCTUnwrap(json["sandbox"] as? [String: Any])
        XCTAssertEqual(sandbox["enableWeakerNestedSandbox"] as? Bool, true)
        XCTAssertEqual(sandbox["excludedCommands"] as? [String], ["git", "docker"])
        XCTAssertEqual(sandbox["enabled"] as? Bool, true)
        XCTAssertNotNil(sandbox["ignoreViolations"])
        let network = try XCTUnwrap(sandbox["network"] as? [String: Any])
        XCTAssertEqual(network["allowLocalBinding"] as? Bool, true)
        XCTAssertNil(network["allowAllUnixSockets"])
        XCTAssertEqual(network["allowedDomains"] as? [String], ["*.github.com"])
        XCTAssertEqual(network["httpProxyPort"] as? Int, 8080)
    }

    // MARK: - autoUpdates lives in ~/.claude.json

    func testAutoUpdatesIsWrittenToGlobalConfigWithoutDroppingKeys() throws {
        let globalURL = home.appendingPathComponent(".claude.json")
        try write(#"{"numStartups":7,"mcpServers":{"x":{"command":"y"}}}"#, to: globalURL)
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertTrue(manager.globalAutoUpdatesEnabled())

        manager.saveGlobalAutoUpdates(false)
        let json = try readJSON(globalURL)
        XCTAssertEqual(json["autoUpdates"] as? Bool, false)
        XCTAssertEqual(json["numStartups"] as? Int, 7)
        XCTAssertNotNil(json["mcpServers"])
        XCTAssertFalse(manager.globalAutoUpdatesEnabled())
        XCTAssertFalse(FileManager.default.fileExists(atPath: settingsPath.path), "settings.json untouched")
    }

    // MARK: - spinnerVerbs

    func testSpinnerVerbsObjectModeWinsOverStaleFlatKey() throws {
        try write(#"{"spinnerVerbsMode":"replace","spinnerVerbs":{"mode":"append","verbs":["Pondering"]}}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertEqual(manager.settings.spinnerVerbsMode, "append")
        XCTAssertEqual(manager.settings.spinnerVerbs, ["Pondering"])
    }

    // MARK: - Commit-on-focus-loss helper

    func testTempHomeNeverTouchesRealClaudeDir() {
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertTrue(manager.settingsURL.path.hasPrefix(home.path))
    }
}
