import XCTest

/// Data-safety tests for the settings.json family. Every test runs against a throwaway home
/// directory (ConfigurationManager(homeDirectory:)) — never the real ~/.claude.
@MainActor
final class SettingsSafetyTests: XCTestCase {

    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-settings-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent(".claude"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    // MARK: - Helpers

    private var settingsPath: URL { home.appendingPathComponent(".claude/settings.json") }

    private func write(_ json: String, to url: URL? = nil) throws {
        let target = url ?? settingsPath
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: target)
    }

    private func readJSON(_ url: URL? = nil) throws -> [String: Any] {
        let data = try Data(contentsOf: url ?? settingsPath)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func decode(_ json: String) throws -> ClaudeSettings {
        try JSONDecoder().decode(ClaudeSettings.self, from: Data(json.utf8))
    }

    // MARK: - Malformed file => no write

    func testMalformedFileIsNeverOverwrittenByFieldSave() throws {
        let garbage = "{ \"model\": \"opus\", \"hooks\": { oops this is not json"
        try write(garbage)
        let manager = ConfigurationManager(homeDirectory: home)

        manager.saveField("theme", value: "dark")

        XCTAssertEqual(try String(contentsOf: settingsPath, encoding: .utf8), garbage)
        XCTAssertNotNil(manager.lastError, "the refused write must be surfaced")
    }

    func testMalformedFileIsNeverOverwrittenByHookSave() throws {
        let garbage = "[1, 2,"
        try write(garbage)
        let manager = ConfigurationManager(homeDirectory: home)

        manager.saveHookGroups([HookGroup(matcherString: "Bash", hooks: [HookDefinition(command: "x")])], event: "PreToolUse")

        XCTAssertEqual(try String(contentsOf: settingsPath, encoding: .utf8), garbage)
        XCTAssertNotNil(manager.lastError)
    }

    func testRootThatIsNotAnObjectIsNotOverwritten() throws {
        try write("[\"a\", \"b\"]")
        let manager = ConfigurationManager(homeDirectory: home)
        manager.saveField("theme", value: "dark")
        XCTAssertEqual(try String(contentsOf: settingsPath, encoding: .utf8), "[\"a\", \"b\"]")
    }

    func testMissingFileIsCreated() throws {
        let manager = ConfigurationManager(homeDirectory: home)
        manager.saveField("theme", value: "dark")
        XCTAssertEqual(try readJSON()["theme"] as? String, "dark")
        XCTAssertNil(manager.lastError)
    }

    func testWholeObjectSaveRefusedWhileDecodeFailed() throws {
        // A top-level array cannot decode into ClaudeSettings, so the flag must trip.
        try write("[1]")
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertTrue(manager.settingsDecodeFailed)

        manager.saveSettings()

        XCTAssertEqual(try String(contentsOf: settingsPath, encoding: .utf8), "[1]")
        XCTAssertNotNil(manager.lastError)
    }

    func testMalformedProjectFileIsNotOverwrittenByProjectSave() throws {
        let project = home.appendingPathComponent("proj")
        let url = project.appendingPathComponent(".claude/settings.json")
        try write("{ broken", to: url)
        let manager = ConfigurationManager(homeDirectory: home)

        var s = ClaudeSettings()
        s.model = "opus"
        manager.saveProjectSettings(s, projectPath: project.path)

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "{ broken")
        XCTAssertNotNil(manager.lastError)
    }

    func testProjectSaveDoesNotInjectDefaults() throws {
        let project = home.appendingPathComponent("proj")
        let url = project.appendingPathComponent(".claude/settings.json")
        try write(#"{"effortLevel": "high", "customKey": {"keep": true}}"#, to: url)
        let manager = ConfigurationManager(homeDirectory: home)

        var s = try XCTUnwrap(manager.loadProjectSettings(projectPath: project.path))
        s.outputStyle = "concise"
        manager.saveProjectSettings(s, projectPath: project.path)

        let json = try readJSON(url)
        XCTAssertEqual(Set(json.keys), ["effortLevel", "customKey", "outputStyle"],
                       "no env/permissions/model defaults may be injected")
        XCTAssertEqual((json["customKey"] as? [String: Any])?["keep"] as? Bool, true)
    }

    func testNilWriteUnderMissingParentCreatesNothing() throws {
        try write(#"{"model": "opus"}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        manager.saveFields([(keyPath: "permissions.allow", value: nil), (keyPath: "sandbox.filesystem.denyRead", value: nil)])
        XCTAssertEqual(Set(try readJSON().keys), ["model"])
    }

    // MARK: - Tolerant decode

    func testAttributionAcceptsBoolAndObject() throws {
        let asBool = try decode(#"{"attribution": false, "model": "opus"}"#)
        XCTAssertEqual(asBool.attribution?.enabled, false)
        XCTAssertEqual(asBool.model, "opus")

        let asObject = try decode(#"{"attribution": {"commit": "c", "pr": "p", "sessionUrl": false}, "model": "opus"}"#)
        XCTAssertEqual(asObject.attribution?.commit, "c")
        XCTAssertEqual(asObject.attribution?.sessionUrl, false)
        XCTAssertEqual(asObject.model, "opus")
    }

    func testSkillOverridesIsARecord() throws {
        let s = try decode(#"{"skillOverrides": {"loop": "off", "review": "name-only"}, "theme": "dark"}"#)
        XCTAssertEqual(s.skillOverrides, ["loop": "off", "review": "name-only"])
        XCTAssertEqual(s.theme, "dark")
        // The legacy single-string form no longer fails the decode.
        let legacy = try decode(#"{"skillOverrides": "off", "theme": "dark"}"#)
        XCTAssertNil(legacy.skillOverrides)
        XCTAssertEqual(legacy.theme, "dark")
    }

    func testSpinnerVerbsObjectDecodes() throws {
        let s = try decode(#"{"spinnerVerbs": {"mode": "replace", "verbs": ["Pondering", "Brewing"]}, "theme": "dark"}"#)
        XCTAssertEqual(s.spinnerVerbs, ["Pondering", "Brewing"])
        XCTAssertEqual(s.spinnerVerbsMode, "replace")
        XCTAssertEqual(s.theme, "dark")
    }

    func testSpinnerTipsMayBeStringsOrObjects() throws {
        let s = try decode("""
        {"spinnerTipsOverride": {"excludeDefault": true, "tipsFile": "t.txt",
          "tips": ["plain", {"id": "a", "text": "object tip"}]}, "theme": "dark"}
        """)
        XCTAssertEqual(s.spinnerTipsOverride?.tips, ["plain", "object tip"])
        XCTAssertEqual(s.spinnerTipsOverride?.excludeDefault, true)
        XCTAssertEqual(s.theme, "dark")
    }

    func testUnknownPreferredGitAppDoesNotThrow() throws {
        let s = try decode(#"{"preferredGitApp": "Lazygit", "theme": "dark"}"#)
        XCTAssertNil(s.preferredGitApp)
        XCTAssertEqual(s.theme, "dark")
    }

    func testOneBadFieldDoesNotDiscardTheRest() throws {
        let s = try decode(#"{"verbose": "yes", "cleanupPeriodDays": "soon", "model": "opus", "env": {"A": 1, "B": true, "C": "x"}}"#)
        XCTAssertNil(s.verbose)
        XCTAssertNil(s.cleanupPeriodDays)
        XCTAssertEqual(s.model, "opus")
        XCTAssertEqual(s.env, ["A": "1", "B": "true", "C": "x"])
    }

    func testBadSettingsFileStillLoadsOnDisk() throws {
        try write(#"{"attribution": false, "skillOverrides": {"a": "off"}, "spinnerVerbs": {"mode": "append", "verbs": ["x"]}, "model": "opus"}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertFalse(manager.settingsDecodeFailed)
        XCTAssertEqual(manager.settings.model, "opus")
    }

    // MARK: - Hooks

    private let hooksFixture = """
    {
      "model": "opus",
      "hooks": {
        "PreToolUse": [
          {"matcher": "Bash", "extraGroupKey": 7, "hooks": [
            {"type": "command", "command": "echo hi", "timeout": 1.5, "async": true, "once": true,
             "shell": "bash", "statusMessage": "Checking", "onFailure": "block", "asyncRewake": true,
             "headers": {"X": "y"}, "model": "haiku", "cloud": {"region": "eu"}},
            {"type": "mcp_tool", "server": "srv", "tool": "t", "input": {"a": [1, 2]}}
          ]}
        ],
        "SomeFutureEvent": [{"hooks": [{"type": "command", "command": "future"}]}],
        "Stop": [{"hooks": [{"type": "command", "command": "stop"}]}]
      }
    }
    """

    func testHookRoundTripKeepsMatcherUnknownFieldsAndDoubleTimeout() throws {
        let s = try decode(hooksFixture)
        let group = try XCTUnwrap(s.hooks?.PreToolUse?.first)
        XCTAssertEqual(group.matcherString, "Bash")
        XCTAssertEqual(group.hooks.count, 2)
        XCTAssertEqual(group.hooks[0].timeout, 1.5)

        let encoded = try JSONEncoder().encode([group])
        let array = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        let g = array[0]
        XCTAssertEqual(g["matcher"] as? String, "Bash", "matcher must stay a plain string")
        XCTAssertEqual(g["extraGroupKey"] as? Int, 7)
        let h0 = try XCTUnwrap((g["hooks"] as? [[String: Any]])?[0])
        XCTAssertEqual(h0["timeout"] as? Double, 1.5)
        XCTAssertEqual(h0["async"] as? Bool, true)
        XCTAssertEqual(h0["once"] as? Bool, true)
        XCTAssertEqual(h0["shell"] as? String, "bash")
        XCTAssertEqual(h0["statusMessage"] as? String, "Checking")
        XCTAssertEqual(h0["onFailure"] as? String, "block")
        XCTAssertEqual(h0["asyncRewake"] as? Bool, true)
        XCTAssertEqual(h0["model"] as? String, "haiku")
        XCTAssertEqual((h0["headers"] as? [String: String])?["X"], "y")
        XCTAssertEqual((h0["cloud"] as? [String: String])?["region"], "eu")
        let h1 = try XCTUnwrap((g["hooks"] as? [[String: Any]])?[1])
        XCTAssertEqual(h1["type"] as? String, "mcp_tool")
        XCTAssertEqual(h1["server"] as? String, "srv")
        XCTAssertEqual(h1["tool"] as? String, "t")
        XCTAssertNotNil(h1["input"] as? [String: Any])
    }

    func testWholeNumberTimeoutIsWrittenAsInteger() throws {
        var def = HookDefinition(command: "x")
        def.timeout = 30
        let text = String(decoding: try JSONEncoder().encode(def), as: UTF8.self)
        XCTAssertTrue(text.contains("\"timeout\":30"), text)
        XCTAssertFalse(text.contains("30.0"), text)
    }

    func testLegacyObjectMatcherIsConvertedToString() throws {
        let s = try decode(#"{"hooks": {"PreToolUse": [{"matcher": {"tool": "Edit"}, "hooks": [{"type": "command", "command": "x"}]}]}}"#)
        XCTAssertEqual(s.hooks?.PreToolUse?.first?.matcherString, "Edit")
    }

    func testSavingOneHookEventTouchesOnlyThatEvent() throws {
        try write(hooksFixture)
        let manager = ConfigurationManager(homeDirectory: home)
        let before = try readJSON()
        let beforeHooks = try XCTUnwrap(before["hooks"] as? [String: Any])

        var groups = try XCTUnwrap(manager.settings.hooks?.Stop)
        groups.append(HookGroup(matcherString: "Bash", hooks: [HookDefinition(command: "another")]))
        manager.saveHookGroups(groups, event: "Stop")

        let after = try readJSON()
        XCTAssertEqual(after["model"] as? String, "opus")
        let hooks = try XCTUnwrap(after["hooks"] as? [String: Any])
        XCTAssertEqual((hooks["Stop"] as? [Any])?.count, 2)
        XCTAssertEqual((hooks["Stop"] as? [[String: Any]])?[1]["matcher"] as? String, "Bash")
        XCTAssertEqual(NSArray(array: hooks["PreToolUse"] as? [Any] ?? []), NSArray(array: beforeHooks["PreToolUse"] as? [Any] ?? []))
        XCTAssertNotNil(hooks["SomeFutureEvent"], "unknown events must survive")
    }

    func testRemovingLastHookEventRemovesEmptyHooksObject() throws {
        try write(#"{"model": "opus", "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "s"}]}]}}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        manager.saveHookGroups([], event: "Stop")
        let json = try readJSON()
        XCTAssertNil(json["hooks"])
        XCTAssertEqual(json["model"] as? String, "opus")
    }

    func testProjectHookSaveUsesProjectFileOnly() throws {
        let project = home.appendingPathComponent("proj")
        let url = project.appendingPathComponent(".claude/settings.json")
        try write(#"{"permissions": {"denyInsteadOfPrompting": true}}"#, to: url)
        let manager = ConfigurationManager(homeDirectory: home)

        manager.saveHookGroups([HookGroup(matcherString: "Bash", hooks: [HookDefinition(command: "p")])],
                               event: "PreToolUse", to: manager.projectSettingsURL(projectPath: project.path))

        let json = try readJSON(url)
        XCTAssertEqual((json["permissions"] as? [String: Any])?["denyInsteadOfPrompting"] as? Bool, true)
        XCTAssertNotNil(json["hooks"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: settingsPath.path))
    }

    // MARK: - Nested unknown-key preservation

    func testSiblingSaveKeepsUnknownNestedKeys() throws {
        try write("""
        {
          "permissions": {"allow": ["Read"], "blockReadsOutsideWorkingDirectories": true, "denyInsteadOfPrompting": true},
          "statusLine": {"type": "command", "command": "a.sh", "refreshInterval": 5, "hideVimModeIndicator": true},
          "worktree": {"baseRef": "head", "location": "../wt"},
          "spinnerTipsOverride": {"excludeDefault": false, "tipsFile": "t.txt", "label": "L"},
          "sandbox": {"enabled": true, "network": {"allowedDomains": ["a.com"]}}
        }
        """)
        let manager = ConfigurationManager(homeDirectory: home)

        manager.saveFields([
            (keyPath: "permissions.allow", value: ["Read", "Edit"]),
            (keyPath: "statusLine.command", value: "b.sh"),
            (keyPath: "worktree.baseRef", value: "fresh"),
            (keyPath: "spinnerTipsOverride.excludeDefault", value: true),
            (keyPath: "sandbox.enabled", value: false)
        ])

        let json = try readJSON()
        let perms = try XCTUnwrap(json["permissions"] as? [String: Any])
        XCTAssertEqual(perms["allow"] as? [String], ["Read", "Edit"])
        XCTAssertEqual(perms["blockReadsOutsideWorkingDirectories"] as? Bool, true)
        XCTAssertEqual(perms["denyInsteadOfPrompting"] as? Bool, true)
        let sl = try XCTUnwrap(json["statusLine"] as? [String: Any])
        XCTAssertEqual(sl["command"] as? String, "b.sh")
        XCTAssertEqual(sl["refreshInterval"] as? Int, 5)
        XCTAssertEqual(sl["hideVimModeIndicator"] as? Bool, true)
        let wt = try XCTUnwrap(json["worktree"] as? [String: Any])
        XCTAssertEqual(wt["baseRef"] as? String, "fresh")
        XCTAssertEqual(wt["location"] as? String, "../wt")
        let tips = try XCTUnwrap(json["spinnerTipsOverride"] as? [String: Any])
        XCTAssertEqual(tips["tipsFile"] as? String, "t.txt")
        XCTAssertEqual(tips["label"] as? String, "L")
        let sb = try XCTUnwrap(json["sandbox"] as? [String: Any])
        XCTAssertNotNil(sb["network"])
    }

    func testEnvChangesAreWrittenPerKey() throws {
        try write(#"{"env": {"KEEP": "1", "DROP": "2", "my.dotted": "3"}, "model": "opus"}"#)
        let manager = ConfigurationManager(homeDirectory: home)

        manager.saveEnvChanges(set: ["NEW": "n"], remove: ["DROP"])

        let env = try XCTUnwrap(try readJSON()["env"] as? [String: String])
        XCTAssertEqual(env, ["KEEP": "1", "NEW": "n", "my.dotted": "3"])
        XCTAssertEqual(try readJSON()["model"] as? String, "opus")
    }

    func testWholeObjectSaveWritesOnlyChangedTopLevelKeys() throws {
        try write(#"{"model": "opus", "futureKey": {"x": 1}, "theme": "dark"}"#)
        let manager = ConfigurationManager(homeDirectory: home)
        manager.settings.theme = "light"
        manager.saveSettings()
        let json = try readJSON()
        XCTAssertEqual(json["theme"] as? String, "light")
        XCTAssertEqual(json["model"] as? String, "opus")
        XCTAssertNotNil(json["futureKey"])
        XCTAssertNil(json["env"])
        XCTAssertNil(json["permissions"])
    }
}
