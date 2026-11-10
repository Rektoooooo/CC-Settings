import XCTest
// The app sources are compiled into this bundle (see project.yml), so the types
// under test are already in-module — no `@testable import CC_Settings` needed.

final class CC_SettingsTests: XCTestCase {

    private func decode(_ json: String) throws -> ClaudeSettings {
        try JSONDecoder().decode(ClaudeSettings.self, from: Data(json.utf8))
    }

    // MARK: - Claude Code 2.1.221 → 2.1.263 keys

    /// Every key added in the 2.1.221–2.1.263 catch-up, with the exact types and enum
    /// values read out of the 2.1.263 binary's zod schemas.
    func testLatestCatchUpKeysDecode() throws {
        let settings = try decode("""
        {
          "timeFormat": "24-hour-utc",
          "timeZone": "Europe/Prague",
          "promptCacheTtl": "1h",
          "bashOutputMaxChars": 64000,
          "taskOutputMaxChars": 48000,
          "autoContinueAtUsageLimit": true,
          "crossSessionInbound": "hold",
          "dialogExpiry": "10m",
          "spellcheck": { "enabled": true, "checker": "aspell", "language": "en_US" }
        }
        """)
        XCTAssertEqual(settings.timeFormat, "24-hour-utc")
        XCTAssertEqual(settings.timeZone, "Europe/Prague")
        XCTAssertEqual(settings.promptCacheTtl, "1h")
        XCTAssertEqual(settings.bashOutputMaxChars, 64000)
        XCTAssertEqual(settings.autoContinueAtUsageLimit, true)
        XCTAssertEqual(settings.crossSessionInbound, "hold")
        XCTAssertEqual(settings.dialogExpiry, "10m")
        XCTAssertEqual(settings.spellcheck?.enabled, true)
        XCTAssertEqual(settings.spellcheck?.checker, "aspell")
        XCTAssertEqual(settings.spellcheck?.language, "en_US")
    }

    /// `spellcheck` is an object in the schema. A bare bool must not take the whole
    /// settings decode down with it.
    func testSpellcheckBoolDoesNotBreakDecoding() throws {
        let settings = try decode(#"{"spellcheck": true, "model": "opus"}"#)
        XCTAssertEqual(settings.model, "opus")
        XCTAssertNil(settings.spellcheck)
    }

    func testModelSwitchHooksDecode() throws {
        let settings = try decode("""
        {
          "hooks": {
            "PreModelSwitch": [{ "hooks": [{ "type": "command", "command": "echo pre" }] }],
            "PostModelSwitch": [{ "hooks": [{ "type": "command", "command": "echo post" }] }]
          }
        }
        """)
        XCTAssertEqual(settings.hooks?.PreModelSwitch?.first?.hooks.first?.command, "echo pre")
        XCTAssertEqual(settings.hooks?.PostModelSwitch?.first?.hooks.first?.command, "echo post")
    }

    /// Every hook event the model knows about must also be offered in the UI, or a
    /// hook set by the CLI is invisible in the app.
    func testHookTypeEnumCoversModelHookEvents() {
        let uiEvents = Set(HookType.allCases.map(\.rawValue))
        XCTAssertTrue(uiEvents.contains("PreModelSwitch"))
        XCTAssertTrue(uiEvents.contains("PostModelSwitch"))
    }

    // MARK: - Claude Code 2.1.171 → 2.1.220 keys

    /// Every key added in the 2.1.171–2.1.220 catch-up, with the exact types the
    /// Claude Code zod schemas declare. Guards against a typo'd CodingKey silently
    /// decoding to nil and the UI then writing a default over the user's value.
    func testCatchUpKeysDecode() throws {
        let settings = try decode("""
        {
          "workflowSizeGuideline": "large",
          "autoCompactWindow": 250000,
          "precomputeCompactionEnabled": true,
          "todoFeatureEnabled": false,
          "askUserQuestionTimeout": "10m",
          "awaySummaryEnabled": false,
          "promptSuggestionEnabled": false,
          "emojiCompletionEnabled": false,
          "fileCheckpointingEnabled": false,
          "feedbackSurveyRate": 0.05,
          "fileSuggestion": { "type": "command", "command": "/bin/suggest" },
          "axScreenReader": true,
          "autoScrollEnabled": false,
          "wheelScrollAccelerationEnabled": false,
          "terminalProgressBarEnabled": true,
          "showMessageTimestamps": true,
          "syntaxHighlightingDisabled": true,
          "hideVimModeIndicator": true,
          "vimInsertModeRemaps": { "jj": "<Esc>", "kk": "<Esc>" },
          "enforceAvailableModels": true,
          "advisorModel": "sonnet",
          "disableAgentView": true,
          "subagentStatusLine": { "type": "command", "command": "/bin/row" },
          "disableRemoteControl": true,
          "remoteControlAtStartup": true,
          "agentPushNotifEnabled": true,
          "enableArtifact": true,
          "disableArtifact": true,
          "disableClaudeAiConnectors": true,
          "channelsEnabled": true,
          "allowedMcpServers": ["github", "sentry"],
          "strictKnownMarketplaces": ["https://example.com/a"],
          "blockedMarketplaces": ["https://example.com/b"],
          "disableSideloadFlags": true,
          "disableSkillShellExecution": true,
          "disableDeepLinkRegistration": "disable"
        }
        """)

        XCTAssertEqual(settings.workflowSizeGuideline, "large")
        XCTAssertEqual(settings.autoCompactWindow, 250_000)
        XCTAssertEqual(settings.precomputeCompactionEnabled, true)
        XCTAssertEqual(settings.todoFeatureEnabled, false)
        XCTAssertEqual(settings.askUserQuestionTimeout, "10m")
        XCTAssertEqual(settings.awaySummaryEnabled, false)
        XCTAssertEqual(settings.promptSuggestionEnabled, false)
        XCTAssertEqual(settings.emojiCompletionEnabled, false)
        XCTAssertEqual(settings.fileCheckpointingEnabled, false)
        XCTAssertEqual(settings.feedbackSurveyRate, 0.05)
        XCTAssertEqual(settings.fileSuggestion?.command, "/bin/suggest")
        XCTAssertEqual(settings.axScreenReader, true)
        XCTAssertEqual(settings.autoScrollEnabled, false)
        XCTAssertEqual(settings.wheelScrollAccelerationEnabled, false)
        XCTAssertEqual(settings.terminalProgressBarEnabled, true)
        XCTAssertEqual(settings.showMessageTimestamps, true)
        XCTAssertEqual(settings.syntaxHighlightingDisabled, true)
        XCTAssertEqual(settings.vimInsertModeRemaps?["jj"], "<Esc>")
        XCTAssertEqual(settings.enforceAvailableModels, true)
        XCTAssertEqual(settings.advisorModel, "sonnet")
        XCTAssertEqual(settings.disableAgentView, true)
        XCTAssertEqual(settings.subagentStatusLine?.command, "/bin/row")
        XCTAssertEqual(settings.disableRemoteControl, true)
        XCTAssertEqual(settings.remoteControlAtStartup, true)
        XCTAssertEqual(settings.agentPushNotifEnabled, true)
        XCTAssertEqual(settings.enableArtifact, true)
        XCTAssertEqual(settings.disableArtifact, true)
        XCTAssertEqual(settings.disableClaudeAiConnectors, true)
        XCTAssertEqual(settings.channelsEnabled, true)
        XCTAssertEqual(settings.allowedMcpServers, ["github", "sentry"])
        XCTAssertEqual(settings.strictKnownMarketplaces, ["https://example.com/a"])
        XCTAssertEqual(settings.blockedMarketplaces, ["https://example.com/b"])
        XCTAssertEqual(settings.disableSideloadFlags, true)
        XCTAssertEqual(settings.disableSkillShellExecution, true)
        XCTAssertEqual(settings.disableDeepLinkRegistration, "disable")
    }

    func testNestedCatchUpKeysDecode() throws {
        let settings = try decode("""
        {
          "attribution": { "commit": "c", "pr": "p", "sessionUrl": false },
          "autoMode": { "allow": ["Bash(ls)"], "classifyAllShell": true },
          "sandbox": {
            "allowAppleEvents": true,
            "credentials": {
              "files": ["~/.netrc"],
              "envVars": ["GITHUB_TOKEN"],
              "allowPlaintextInject": true
            },
            "filesystem": { "allowWrite": ["/tmp"], "disabled": true },
            "network": {
              "allowedDomains": ["a.com"],
              "deniedDomains": ["b.com"],
              "strictAllowlist": true,
              "allowManagedDomainsOnly": true
            }
          }
        }
        """)

        XCTAssertEqual(settings.attribution?.sessionUrl, false)
        XCTAssertEqual(settings.attribution?.commit, "c")
        XCTAssertEqual(settings.autoMode?.classifyAllShell, true)
        XCTAssertEqual(settings.autoMode?.allow, ["Bash(ls)"])
        XCTAssertEqual(settings.sandbox?.allowAppleEvents, true)
        XCTAssertEqual(settings.sandbox?.credentials?.files, ["~/.netrc"])
        XCTAssertEqual(settings.sandbox?.credentials?.envVars, ["GITHUB_TOKEN"])
        XCTAssertEqual(settings.sandbox?.credentials?.allowPlaintextInject, true)
        XCTAssertEqual(settings.sandbox?.filesystem?.disabled, true)
        XCTAssertEqual(settings.sandbox?.filesystem?.allowWrite, ["/tmp"])
        XCTAssertEqual(settings.sandbox?.network?.deniedDomains, ["b.com"])
        XCTAssertEqual(settings.sandbox?.network?.strictAllowlist, true)
        XCTAssertEqual(settings.sandbox?.network?.allowManagedDomainsOnly, true)
    }

    /// `sessionUrl` defaults to true, so an attribution block without it must not
    /// read as an opt-out.
    func testAttributionSessionUrlDefaultsToNil() throws {
        let settings = try decode(#"{"attribution": {"commit": "c"}}"#)
        XCTAssertNil(settings.attribution?.sessionUrl)
    }

    // MARK: - Hooks

    func testNewHookEventsDecode() throws {
        let settings = try decode("""
        {
          "hooks": {
            "DirectoryAdded":      [{"hooks": [{"type": "command", "command": "a"}]}],
            "PostToolBatch":       [{"hooks": [{"type": "command", "command": "b"}]}],
            "StopFailure":         [{"hooks": [{"type": "command", "command": "c"}]}],
            "UserPromptExpansion": [{"hooks": [{"type": "command", "command": "d"}]}],
            "TaskCreated":         [{"hooks": [{"type": "command", "command": "e"}]}],
            "CwdChanged":          [{"hooks": [{"type": "command", "command": "f"}]}],
            "FileChanged":         [{"hooks": [{"type": "command", "command": "g"}]}]
          }
        }
        """)

        let hooks = try XCTUnwrap(settings.hooks)
        XCTAssertEqual(hooks.DirectoryAdded?.first?.hooks.first?.command, "a")
        XCTAssertEqual(hooks.PostToolBatch?.first?.hooks.first?.command, "b")
        XCTAssertEqual(hooks.StopFailure?.first?.hooks.first?.command, "c")
        XCTAssertEqual(hooks.UserPromptExpansion?.first?.hooks.first?.command, "d")
        XCTAssertEqual(hooks.TaskCreated?.first?.hooks.first?.command, "e")
        XCTAssertEqual(hooks.CwdChanged?.first?.hooks.first?.command, "f")
        XCTAssertEqual(hooks.FileChanged?.first?.hooks.first?.command, "g")
    }

    /// Every `HookType` the UI offers must map to a real `HooksConfig` field,
    /// otherwise editing that hook silently writes nothing.
    func testEveryHookTypeIsBackedByAConfigField() throws {
        for type in HookType.allCases {
            let json = """
            {"hooks": {"\(type.rawValue)": [{"hooks": [{"type": "command", "command": "x"}]}]}}
            """
            let settings = try decode(json)
            let encoded = try JSONEncoder().encode(settings.hooks)
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: encoded) as? [String: Any]
            )
            XCTAssertNotNil(
                object[type.rawValue],
                "HookType.\(type.rawValue) has no matching HooksConfig property"
            )
        }
    }

    // MARK: - Model catalog

    func testCurrentAndPreviousVersionsArePickable() {
        let opus = versions(for: .opus).map(\.modelId)
        XCTAssertTrue(opus.contains("claude-opus-5-5"))
        XCTAssertTrue(opus.contains("claude-opus-5"))
        XCTAssertFalse(opus.contains("claude-opus-5-5[1m]"))
        XCTAssertFalse(opus.contains("claude-opus-5[1m]"))

        let sonnet = versions(for: .sonnet).map(\.modelId)
        XCTAssertTrue(sonnet.contains("claude-sonnet-5-5"))
        XCTAssertTrue(sonnet.contains("claude-sonnet-5"))
        XCTAssertFalse(sonnet.contains("claude-sonnet-5[1m]"))

        let haiku = versions(for: .haiku).map(\.modelId)
        XCTAssertTrue(haiku.contains("claude-haiku-5-5"))
        XCTAssertTrue(haiku.contains("claude-haiku-4-5-20251001"))
    }

    /// `/model` still accepts these aliases; hidden rows must keep resolving to a name/family.
    func testTerminalWrittenAliasesStillResolve() {
        let opus = versions(for: .opus).map(\.modelId)
        XCTAssertTrue(opus.contains("opusplan"))
        XCTAssertFalse(opus.contains("opus[1m]"))
        XCTAssertFalse(versions(for: .sonnet).map(\.modelId).contains("sonnet[1m]"))
        XCTAssertEqual(family(for: "opus[1m]"), .opus)
        XCTAssertEqual(displayName(for: "sonnet[1m]"), "Sonnet (latest)")
        XCTAssertEqual(displayName(for: "claude-opus-5-5[1m]"), "Opus 5.5")
    }

    func testFableFiveTwoIsTheCurrentFable() {
        let fable = versions(for: .fable).map(\.modelId)
        XCTAssertTrue(fable.contains("claude-fable-5-2"))
        // Fable 5.1 is migrated to the `fable` alias and has no row; 5 is long gone.
        XCTAssertFalse(fable.contains("claude-fable-5-1"))
        XCTAssertFalse(fable.contains("claude-fable-5"))
        XCTAssertEqual(displayName(for: "claude-fable-5-1"), "Fable 5.1")
    }

    func testNoVisibleRowOffersOneMillionSuffix() {
        for family in ModelFamily.allCases {
            let offered = versions(for: family).map(\.modelId)
            XCTAssertFalse(offered.contains { $0.hasSuffix("[1m]") }, "\(family) offers \(offered)")
        }
    }

    func testLegacyFableSuffixStillResolves() {
        XCTAssertEqual(displayName(for: "claude-fable-5[1m]"), "Fable 5")
    }

    func testEachFamilyOffersExactlyOneCurrentVersion() {
        for family in ModelFamily.allCases {
            let current = versions(for: family).filter { $0.kind == .current }
            XCTAssertEqual(
                current.count, 1,
                "\(family.rawValue) should offer one current version, got \(current.map(\.modelId))"
            )
        }
    }

    func testCanonicalModelId() {
        XCTAssertEqual(canonicalModelId("opus"), "claude-opus-5-5")
        XCTAssertEqual(canonicalModelId("opus[1m]"), "claude-opus-5-5")
        XCTAssertEqual(canonicalModelId("claude-opus-5-5[1m]"), "claude-opus-5-5")
        XCTAssertEqual(canonicalModelId("claude-sonnet-4-5-20250929"), "claude-sonnet-4-5")
        XCTAssertEqual(canonicalModelId("opusplan"), "claude-sonnet-5-5")
        XCTAssertEqual(canonicalModelId("fable"), "claude-fable-5-2")
        XCTAssertEqual(canonicalModelId("best"), "claude-opus-5-5")
        XCTAssertEqual(canonicalModelId("us.anthropic.claude-sonnet-4-5-20250929-v1:0"), "claude-sonnet-4-5")
        XCTAssertEqual(canonicalModelId("claude-sonnet-4-5@20250929"), "claude-sonnet-4-5")
        XCTAssertEqual(canonicalModelId(""), "")
    }

    func testUnknownKeysDoNotBreakDecoding() throws {
        let settings = try decode(#"{"model": "opus", "someFutureKey": {"nested": 1}}"#)
        XCTAssertEqual(settings.model, "opus")
    }
}
