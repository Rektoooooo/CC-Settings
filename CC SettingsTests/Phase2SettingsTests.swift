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

    // MARK: - Hooks

    func testLegacyToolPatternMatcherLoadsAsToolOnly() throws {
        let json = #"{"matcher":{"tool":"Bash","pattern":"git push.*"},"hooks":[{"type":"command","command":"x","if":"Bash(git *)"}]}"#
        let group = try JSONDecoder().decode(HookGroup.self, from: Data(json.utf8))
        XCTAssertEqual(group.matcherString, "Bash")
        XCTAssertEqual(group.hooks.first?.ifCondition, "Bash(git *)")
    }

    func testHookGroupModelKeepsSingleMatcherAndIfFilter() throws {
        let group = HookGroup(matcherString: "Bash|Edit", hooks: [HookDefinition(command: "echo hi", ifCondition: "Bash(git *)")])
        var model = HookGroupModel(from: group)
        XCTAssertEqual(model.matcher, "Bash|Edit")
        XCTAssertEqual(model.ifList, ["Bash(git *)"])

        model.matcher = "  mcp__.*  "
        model.ifList = [""]
        let saved = model.toHookGroup()
        XCTAssertEqual(saved.matcherString, "mcp__.*")
        XCTAssertNil(saved.hooks.first?.ifCondition)

        model.matcher = ""
        XCTAssertNil(model.toHookGroup().matcherString, "empty matcher matches everything and is omitted")
    }

    // MARK: - Themes

    private func themeURL(_ slug: String) -> URL {
        home.appendingPathComponent(".claude/themes/\(slug).json")
    }

    func testThemeFileRoundTripsNameBaseOverridesAndKeepsUnknownKeys() throws {
        let json = ##"{"name":"Midnight","base":"light","overrides":{"claude":"#112233","notAPaletteKey":"#ffffff","success":42},"futureField":{"a":1}}"##
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        var theme = ThemeFile.parse(object, id: "midnight", url: themeURL("midnight"))

        XCTAssertEqual(theme.name, "Midnight")
        XCTAssertEqual(theme.base, "light")
        XCTAssertEqual(theme.overrides, ["claude": "#112233"])
        XCTAssertNotNil(theme.extraOverrides["notAPaletteKey"], "unmodeled override entries are preserved")
        XCTAssertNotNil(theme.extraOverrides["success"], "non-string override values are preserved")
        XCTAssertFalse(theme.needsLegacyConversion)

        theme.overrides["error"] = "#ff0000"
        let out = try XCTUnwrap(JSONSerialization.jsonObject(with: theme.serialize()) as? [String: Any])
        XCTAssertEqual(out["name"] as? String, "Midnight")
        XCTAssertEqual(out["base"] as? String, "light")
        XCTAssertNotNil(out["futureField"])
        let overrides = try XCTUnwrap(out["overrides"] as? [String: Any])
        XCTAssertEqual(overrides["claude"] as? String, "#112233")
        XCTAssertEqual(overrides["error"] as? String, "#ff0000")
        XCTAssertEqual(overrides["notAPaletteKey"] as? String, "#ffffff")
        XCTAssertEqual(overrides["success"] as? Int, 42)
    }

    func testNewThemeMatchesCLIDefaultShape() throws {
        let theme = ThemeFile(id: "my-theme", url: themeURL("my-theme"))
        let out = try XCTUnwrap(JSONSerialization.jsonObject(with: theme.serialize()) as? [String: Any])
        XCTAssertEqual(out["name"] as? String, "my-theme")
        XCTAssertEqual(out["base"] as? String, "dark")
        XCTAssertEqual((out["overrides"] as? [String: Any])?.count, 0)
    }

    func testUnknownBaseFallsBackToDarkLikeTheCLI() {
        let theme = ThemeFile(id: "x", url: themeURL("x"), base: "solarized")
        XCTAssertEqual(theme.base, "dark")
    }

    func testPaletteHasTheDocumentedKeysForEveryBase() {
        for base in ClaudeThemePalette.baseNames {
            for key in ["promptBorder", "bashBorder", "diffAdded", "claude", "success"] {
                XCTAssertNotNil(ClaudeThemePalette.value(base: base, key: key), "\(base).\(key)")
            }
        }
        XCTAssertEqual(ClaudeThemePalette.keys.count, 72)
    }

    func testFlatFormatThemeIsDetectedAndConvertedWithoutLosingData() throws {
        let flat = ##"{"name":"old","description":"mine","accent":"#4a90e2","error":"#ff5555","keyword":"#ff79c6","ansiRed":"#ff0000"}"##
        try FileManager.default.createDirectory(at: themeURL("old").deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(flat.utf8).write(to: themeURL("old"))
        let manager = ConfigurationManager(homeDirectory: home)

        let loaded = try XCTUnwrap(manager.loadThemes().first)
        XCTAssertTrue(loaded.needsLegacyConversion)
        XCTAssertTrue(loaded.overrides.isEmpty, "flat colours are not honoured by Claude Code, so they are not overrides yet")
        XCTAssertEqual(loaded.base, "dark")

        let converted = try manager.convertLegacyTheme(loaded)
        XCTAssertFalse(converted.needsLegacyConversion)
        XCTAssertEqual(converted.overrides["claude"], "#4a90e2")
        XCTAssertEqual(converted.overrides["error"], "#ff5555")

        let onDisk = try readJSON(themeURL("old"))
        XCTAssertEqual(onDisk["base"] as? String, "dark")
        XCTAssertEqual((onDisk["overrides"] as? [String: Any])?["error"] as? String, "#ff5555")
        XCTAssertEqual(onDisk["keyword"] as? String, "#ff79c6", "unmapped colours stay in the file")
        XCTAssertEqual(onDisk["ansiRed"] as? String, "#ff0000")
        XCTAssertEqual(onDisk["description"] as? String, "mine")
        let backup = themeURL("old").appendingPathExtension("bak")
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), flat, "original kept as .bak")
    }

    func testCustomThemeActivationValueUsesCustomPrefix() throws {
        XCTAssertEqual(ThemeFile.activationValue(forSlug: "midnight"), "custom:midnight")
        XCTAssertEqual(ThemeFile.slug(fromActivationValue: "custom:midnight"), "midnight")
        XCTAssertNil(ThemeFile.slug(fromActivationValue: "midnight"))
        XCTAssertNil(ThemeFile.slug(fromActivationValue: "dark"))
        XCTAssertNil(ThemeFile.slug(fromActivationValue: nil))

        let manager = ConfigurationManager(homeDirectory: home)
        manager.saveField("theme", value: ThemeFile.activationValue(forSlug: "midnight"))
        XCTAssertEqual(try readJSON()["theme"] as? String, "custom:midnight")
        XCTAssertEqual(manager.settings.theme, "custom:midnight")
    }

    func testSlugFollowsTheCLIRule() {
        XCTAssertEqual(ThemeFile.slug(from: "My Cool Theme!"), "my-cool-theme")
        XCTAssertEqual(ThemeFile.slug(from: "  --Nord__v2--  "), "nord-v2")
        XCTAssertEqual(ThemeFile.slug(from: "***"), "theme")
        XCTAssertEqual(ThemeFile.slug(from: "solarized-dark"), "solarized-dark")
    }

    func testThemeColorValueParsesCLIColourSyntaxes() {
        XCTAssertEqual(ThemeColorValue.rgb("rgb(215,119,87)")?.r, 215)
        XCTAssertEqual(ThemeColorValue.rgb("#fff")?.g, 255)
        XCTAssertEqual(ThemeColorValue.rgb("#0a141e")?.b, 30)
        XCTAssertNotNil(ThemeColorValue.rgb("ansi:redBright"))
        XCTAssertNotNil(ThemeColorValue.rgb("ansi256(196)"))
        XCTAssertNil(ThemeColorValue.rgb("ansi:notacolor"))
        XCTAssertNil(ThemeColorValue.rgb("red"))
    }

    // MARK: - Commit-on-focus-loss helper

    func testTempHomeNeverTouchesRealClaudeDir() {
        let manager = ConfigurationManager(homeDirectory: home)
        XCTAssertTrue(manager.settingsURL.path.hasPrefix(home.path))
    }
}
