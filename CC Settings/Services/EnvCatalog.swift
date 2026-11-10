import Foundation

/// One environment variable the Environment screen offers as a plain field or toggle.
/// Every name here was found in the Claude Code 2.1.322 binary.
struct EnvVarSpec: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Truthy flag written as "1"; absent when off.
        case flag
        /// Free text, trimmed; empty removes the variable.
        case text(placeholder: String)
    }

    let key: String
    let title: String
    let help: String
    let kind: Kind

    var id: String { key }
}

struct EnvVarGroup: Identifiable, Equatable {
    let title: String
    let vars: [EnvVarSpec]
    var id: String { title }
}

/// Variables added for Claude Code 2.1.322. Driven by data so the screen, the managed-key
/// set and the tests share one list.
enum EnvCatalog {
    private static func text(_ key: String, _ title: String, _ placeholder: String, _ help: String) -> EnvVarSpec {
        EnvVarSpec(key: key, title: title, help: help, kind: .text(placeholder: placeholder))
    }

    private static func flag(_ key: String, _ title: String, _ help: String) -> EnvVarSpec {
        EnvVarSpec(key: key, title: title, help: help, kind: .flag)
    }

    static let groups: [EnvVarGroup] = [
        EnvVarGroup(title: "Model Picker Labels", vars: [
            text("ANTHROPIC_DEFAULT_FABLE_MODEL_NAME", "Fable Pin Name", "e.g. Fable (corp gateway)",
                 "Display name for the pinned fable model in the /model picker."),
            text("ANTHROPIC_DEFAULT_FABLE_MODEL_DESCRIPTION", "Fable Pin Description", "short description",
                 "Description shown under the pinned fable model in the /model picker."),
            text("ANTHROPIC_DEFAULT_OPUS_MODEL_NAME", "Opus Pin Name", "e.g. Opus (corp gateway)",
                 "Display name for the pinned opus model in the /model picker."),
            text("ANTHROPIC_DEFAULT_OPUS_MODEL_DESCRIPTION", "Opus Pin Description", "short description",
                 "Description shown under the pinned opus model in the /model picker."),
            text("ANTHROPIC_DEFAULT_SONNET_MODEL_NAME", "Sonnet Pin Name", "e.g. Sonnet (corp gateway)",
                 "Display name for the pinned sonnet model in the /model picker."),
            text("ANTHROPIC_DEFAULT_SONNET_MODEL_DESCRIPTION", "Sonnet Pin Description", "short description",
                 "Description shown under the pinned sonnet model in the /model picker."),
            text("ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME", "Haiku Pin Name", "e.g. Haiku (corp gateway)",
                 "Display name for the pinned haiku model in the /model picker."),
            text("ANTHROPIC_DEFAULT_HAIKU_MODEL_DESCRIPTION", "Haiku Pin Description", "short description",
                 "Description shown under the pinned haiku model in the /model picker."),
            text("ANTHROPIC_CUSTOM_MODEL_OPTION", "Custom Model Option", "e.g. my-gateway-model",
                 "Adds one extra model ID to the /model picker, after the built-in lineup."),
            text("ANTHROPIC_CUSTOM_MODEL_OPTION_NAME", "Custom Option Name", "label",
                 "Display name for the custom model option."),
            text("ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION", "Custom Option Description", "short description",
                 "Description for the custom model option."),
        ]),
        EnvVarGroup(title: "Vertex AI Regions", vars: [
            text("VERTEX_REGION_CLAUDE_5_5_OPUS", "Opus 5.5 Region", "e.g. global, us-east5",
                 "Vertex region for claude-opus-5-5. Only used when running on Vertex AI."),
            text("VERTEX_REGION_CLAUDE_5_5_SONNET", "Sonnet 5.5 Region", "e.g. global, us-east5",
                 "Vertex region for claude-sonnet-5-5."),
            text("VERTEX_REGION_CLAUDE_HAIKU_5_5", "Haiku 5.5 Region", "e.g. global, us-east5",
                 "Vertex region for claude-haiku-5-5."),
            text("VERTEX_REGION_CLAUDE_FABLE_5_2", "Fable 5.2 Region", "e.g. global, us-east5",
                 "Vertex region for claude-fable-5-2. Older models have matching VERTEX_REGION_CLAUDE_* variables; add them under Custom Variables."),
        ]),
        EnvVarGroup(title: "Subagents & Workflows", vars: [
            text("CLAUDE_CODE_SUBAGENT_EFFORT", "Subagent Effort", "low / medium / high / xhigh / max",
                 "Effort level subagents run at. Accepts the same levels as the effort setting."),
            text("CLAUDE_CODE_WORKFLOW_SUBAGENT_MODEL", "Workflow Subagent Model", "e.g. claude-sonnet-5-5",
                 "Model for agents spawned by workflows. Ignored when CLAUDE_CODE_SUBAGENT_MODEL_FORCE is on."),
            flag("CLAUDE_CODE_LOOP_KEEPALIVE", "Keep /loop Alive",
                 "Restores the old self-paced /loop behavior: schedule a fallback wakeup instead of ending when a turn finishes without rescheduling."),
        ]),
        EnvVarGroup(title: "Compaction, Thinking & Fallback", vars: [
            text("CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS", "Idle Compaction Minimum", "tokens",
                 "Minimum conversation size, in tokens, before idle compaction runs. Pairs with the Idle Compaction setting in General."),
            flag("CLAUDE_CODE_DISABLE_ULTRATHINK", "Disable ultrathink Keyword",
                 "Stop the word \"ultrathink\" in a prompt from raising thinking effort."),
            text("CLAUDE_CODE_AUTO_MODE_MODEL", "Auto Mode Classifier Model", "model id",
                 "Model for the auto mode classifier. A server-configured classifier model takes priority."),
            flag("CLAUDE_CODE_DISABLE_REFUSAL_FALLBACK", "Disable Refusal Fallback",
                 "Turn off automatic model switches after a flagged message, including for unrecognized model names."),
        ]),
        EnvVarGroup(title: "Tools, MCP & Attribution", vars: [
            flag("CLAUDE_CODE_DISABLE_WEB_FETCH", "Disable WebFetch",
                 "Remove the WebFetch tool."),
            flag("CLAUDE_CODE_DISABLE_FILE_MENTIONS", "Disable @ File Mentions",
                 "Turn off @ file mention handling in prompts."),
            flag("CLAUDE_CODE_DISABLE_MCP_TASKS", "Disable MCP Tasks",
                 "Turn off MCP task support, where a server runs a long tool call as a task."),
            flag("CLAUDE_CODE_DISABLE_MCP_TASK_BACKGROUND", "Wait for MCP Tasks",
                 "Wait for an MCP task inside its tool call instead of moving it to the background right away."),
            text("CLAUDE_CODE_MAX_MCP_DESCRIPTION_LENGTH", "MCP Description Limit", "characters",
                 "Cap on the length of MCP tool descriptions sent to the model."),
            text("CLAUDE_CODE_ATTRIBUTION_PROJECT", "Attribution Project", "claude_proj_… or chan_…",
                 "claude.ai Project named in usage reports. Takes precedence over the attributionProject setting and also works in folders nobody has trusted, such as CI."),
        ]),
    ]

    static let allKeys: Set<String> = Set(groups.flatMap { $0.vars.map(\.key) })

    /// Variables the app used to catalog that no longer exist in Claude Code 2.1.322.
    /// They stay editable under Custom Variables if a settings file still has them.
    static let retiredKeys: Set<String> = ["API_BASE_URL", "CLAUDE_CODE_HIDE_ACCOUNT_INFO", "DISABLE_NON_ESSENTIAL_MODEL_CALLS"]

    /// Values accepted by `CLAUDE_CODE_EFFORT_LEVEL`: the effort levels, plus `unset` / `auto`
    /// to ignore the setting.
    static let effortLevelHint = "low / medium / high / xhigh / max / auto / unset"

    /// The env entries these screen values produce: flags become "1", text is trimmed, and
    /// empty or off entries are omitted.
    static func entries(from values: [String: String]) -> [String: String] {
        var result: [String: String] = [:]
        for group in groups {
            for spec in group.vars {
                guard let raw = values[spec.key] else { continue }
                switch spec.kind {
                case .flag:
                    if raw == "1" { result[spec.key] = "1" }
                case .text:
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { result[spec.key] = trimmed }
                }
            }
        }
        return result
    }
}
