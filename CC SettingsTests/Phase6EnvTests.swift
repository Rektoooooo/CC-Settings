import XCTest
@testable import CC_Settings

@MainActor
final class Phase6EnvTests: XCTestCase {

    func testCatalogKeysAreUniqueAndHaveHelp() {
        let all = EnvCatalog.groups.flatMap(\.vars)
        XCTAssertEqual(all.count, Set(all.map(\.key)).count, "duplicate key in catalog")
        XCTAssertEqual(EnvCatalog.allKeys.count, all.count)
        for spec in all {
            XCTAssertFalse(spec.help.isEmpty, spec.key)
            XCTAssertFalse(spec.title.isEmpty, spec.key)
        }
    }

    func testRequestedVariablesAreCataloged() {
        let expected = [
            "VERTEX_REGION_CLAUDE_5_5_OPUS", "VERTEX_REGION_CLAUDE_5_5_SONNET",
            "VERTEX_REGION_CLAUDE_HAIKU_5_5", "VERTEX_REGION_CLAUDE_FABLE_5_2",
            "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME", "ANTHROPIC_DEFAULT_SONNET_MODEL_DESCRIPTION",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME", "ANTHROPIC_DEFAULT_FABLE_MODEL_DESCRIPTION",
            "ANTHROPIC_CUSTOM_MODEL_OPTION", "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME",
            "ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION", "CLAUDE_CODE_SUBAGENT_EFFORT",
            "CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS", "CLAUDE_CODE_DISABLE_ULTRATHINK",
            "CLAUDE_CODE_ATTRIBUTION_PROJECT", "CLAUDE_CODE_DISABLE_WEB_FETCH",
            "CLAUDE_CODE_DISABLE_FILE_MENTIONS", "CLAUDE_CODE_AUTO_MODE_MODEL",
            "CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL", "CLAUDE_CODE_DISABLE_MCP_TASKS",
            "CLAUDE_CODE_DISABLE_MCP_TASK_BACKGROUND", "CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH",
            "CLAUDE_CODE_LOOP_KEEPALIVE", "CLAUDE_CODE_DISABLE_REFUSAL_FALLBACK",
        ]
        for key in expected { XCTAssertTrue(EnvCatalog.allKeys.contains(key), key) }
    }

    func testRetiredKeysAreNotManagedOrCataloged() {
        for key in EnvCatalog.retiredKeys {
            XCTAssertFalse(EnvCatalog.allKeys.contains(key), key)
            XCTAssertFalse(EnvironmentView.managedKeys.contains(key), "\(key) must surface as a custom variable")
        }
        XCTAssertTrue(EnvironmentView.managedKeys.contains("ANTHROPIC_BASE_URL"))
        XCTAssertTrue(EnvCatalog.allKeys.isSubset(of: EnvironmentView.managedKeys))
    }

    func testEntriesFlagsBecomeOneAndTextIsTrimmed() {
        let entries = EnvCatalog.entries(from: [
            "CLAUDE_CODE_DISABLE_WEB_FETCH": "1",
            "CLAUDE_CODE_DISABLE_ULTRATHINK": "",
            "CLAUDE_CODE_SUBAGENT_EFFORT": "  high  ",
            "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME": "   ",
            "NOT_IN_CATALOG": "x",
        ])
        XCTAssertEqual(entries, [
            "CLAUDE_CODE_DISABLE_WEB_FETCH": "1",
            "CLAUDE_CODE_SUBAGENT_EFFORT": "high",
        ])
    }
}
