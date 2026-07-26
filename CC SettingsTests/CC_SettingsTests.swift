import XCTest
@testable import CC_Settings

final class CC_SettingsTests: XCTestCase {

    private func decode(_ json: String) throws -> ClaudeSettings {
        try JSONDecoder().decode(ClaudeSettings.self, from: Data(json.utf8))
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
        XCTAssertEqual(settings.hideVimModeIndicator, true)
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

    func testOpusFiveAndSonnetFiveArePickable() {
        let opus = versions(for: .opus).map(\.modelId)
        XCTAssertTrue(opus.contains("claude-opus-5"))
        XCTAssertTrue(opus.contains("claude-opus-5[1m]"))

        let sonnet = versions(for: .sonnet).map(\.modelId)
        XCTAssertTrue(sonnet.contains("claude-sonnet-5"))
    }

    /// Only Opus exposes a `[1m]` suffix variant. Fable 5 and Sonnet 5 are natively
    /// 1M-context and Claude Code's catalog gives them no `supports_1m_suffix`, so
    /// offering `claude-fable-5[1m]` / `claude-sonnet-5[1m]` would write a model ID
    /// the CLI does not recognise as a distinct variant.
    func testNoBogusOneMillionSuffixVariantsInPicker() {
        for family in [ModelFamily.fable, .sonnet] {
            let offered = versions(for: family).map(\.modelId)
            XCTAssertFalse(
                offered.contains { $0.hasSuffix("[1m]") },
                "\(family.rawValue) must not offer a [1m] variant, got \(offered)"
            )
        }
    }

    /// The bad `claude-fable-5[1m]` entry shipped in v1.5.0 stays in the catalog so
    /// configs written by that build still render a readable name.
    func testLegacyFableSuffixStillResolves() {
        XCTAssertEqual(displayName(for: "claude-fable-5[1m]"), "Fable 5")
    }

    func testEachFamilyOffersExactlyOneCurrentVersion() {
        for family in ModelFamily.allCases {
            let concrete = versions(for: family).filter { !$0.isLatest }
            let base = concrete.filter { !$0.modelId.hasSuffix("[1m]") }
            XCTAssertEqual(
                base.count, 1,
                "\(family.rawValue) should offer one current version, got \(base.map(\.modelId))"
            )
        }
    }

    func testUnknownKeysDoNotBreakDecoding() throws {
        let settings = try decode(#"{"model": "opus", "someFutureKey": {"nested": 1}}"#)
        XCTAssertEqual(settings.model, "opus")
    }
}
