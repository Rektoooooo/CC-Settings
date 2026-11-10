import Foundation

struct ClaudeSettings: Equatable {
    var apiKeyHelper: String?
    var env: [String: String] = [:]
    var permissions: PermissionsConfig = PermissionsConfig()
    /// Empty string == no `model` key in settings.json (Claude Code uses its own
    /// default). Do NOT default this to a concrete model — that fabricates a
    /// selection the user never made.
    var model: String = ""
    var hooks: HooksConfig?
    var skipWebFetchPreflight: Bool?
    var alwaysThinkingEnabled: Bool?
    /// Top-level in Claude Code (not under `permissions`).
    var skipDangerousModePermissionPrompt: Bool?
    var mainBranch: String?
    var preferredGitApp: GitAppPreference?
    var customGitAppPath: String?

    // Appearance & Output
    var theme: String?
    var language: String?
    var effortLevel: String?
    /// Inverted master switch for dynamic workflows / ultracode. `true` disables the
    /// feature (and removes `ultracode` from the effort menu). Default unset == enabled.
    var disableWorkflows: Bool?
    /// Whether typing "ultracode" in a prompt triggers a dynamic workflow.
    /// Default unset == enabled; write `false` to require explicit /workflows.
    var workflowKeywordTriggerEnabled: Bool?
    var outputStyle: String?
    var verbose: Bool?
    var prefersReducedMotion: Bool?
    /// Per-skill visibility: `{ "<skillName>": "on" | "name-only" | "user-invocable-only" | "off" }`.
    /// Read-only in the UI; edited by hand in settings.json (writes never touch it).
    var skillOverrides: [String: String]?
    /// Inverted: `true` hides Claude Code's bundled skills (/code-review, /loop, …)
    /// from the model. Default unset == bundled skills visible.
    var disableBundledSkills: Bool?

    /// Advisory ceiling on how many agents the workflows Claude writes may use.
    /// `unrestricted` / `small` (<5) / `medium` (<15, the default) / `large` (<50).
    var workflowSizeGuideline: String?

    // Behavior
    var showTurnDuration: Bool?
    var respectGitignore: Bool?
    var autoCompactEnabled: Bool?
    var plansDirectory: String?
    var includeGitInstructions: Bool?
    var showThinkingSummaries: Bool?
    var showClearContextOnPlanAccept: Bool?
    var defaultShell: String?
    /// Auto-compact window size in tokens. Claude Code clamps this to 100_000…1_000_000.
    var autoCompactWindow: Int?
    /// Build the compaction summary in the background before it's needed.
    /// Only has an effect while auto-compact is on.
    var precomputeCompactionEnabled: Bool?
    /// Enables the todo / task tracking panel.
    var todoFeatureEnabled: Bool?
    /// Idle time before an unanswered AskUserQuestion auto-continues.
    /// One of `60s`, `5m`, `10m`, `never`.
    var askUserQuestionTimeout: String?
    /// Default unset == enabled. `false` disables the "while you were away" recap.
    var awaySummaryEnabled: Bool?
    /// Default unset == enabled. `false` disables prompt suggestions.
    var promptSuggestionEnabled: Bool?
    /// Default unset == enabled. `false` disables the `:shortcode:` emoji typeahead.
    var emojiCompletionEnabled: Bool?
    /// Snapshot files before edits so `/rewind` can restore them.
    var fileCheckpointingEnabled: Bool?
    /// Probability (0–1) that the session quality survey appears when eligible.
    var feedbackSurveyRate: Double?
    /// Custom script backing `@` file autocomplete.
    var fileSuggestion: CommandScriptConfig?
    /// Wait out a claude.ai usage limit and resume the task automatically. Default
    /// unset == off, in which case the limit dialog offers the wait as a choice.
    var autoContinueAtUsageLimit: Bool?
    /// Characters of a successful Bash/PowerShell result Claude receives inline.
    /// Default 30_000; Claude Code clamps to 4_000…128_000.
    var bashOutputMaxChars: Int?
    /// Compact a long conversation while the session is idle. CLI default true.
    var idleCompaction: Bool?
    /// Maximum width (terminal columns, min 40) of the prose in responses. Unset = full width.
    var maxProseWidth: Int?
    /// Show a diff of files a Bash command changed. Tri-state: unset follows the CLI default.
    var bashEditDiffEnabled: Bool?
    /// Auto-switch model when safeguards flag a message. CLI default true.
    var switchModelsOnFlag: Bool?
    /// Only `false` is honoured by the CLI (read from user/local/managed, not project).
    var syncClaudeAiSkills: Bool?
    var syncClaudeAiPlugins: Bool?
    /// claude.ai Project named in usage reports (`claude_proj_…` / `chan_…`).
    var attributionProject: String?
    /// Characters of a background task's output `TaskOutput` hands Claude inline.
    /// Default 32_000; Claude Code clamps to 4_000…128_000.

    // Time & Locale
    /// Clock format for times in the UI: `auto` (default, follows locale), `12-hour`,
    /// `24-hour`, `24-hour-utc`, or a strftime pattern (any value containing `%`).
    var timeFormat: String?
    /// IANA time zone for times in the UI, e.g. `UTC` or `Europe/Prague`.
    /// Default unset == the system time zone; an unknown name falls back to it.
    var timeZone: String?

    // Terminal & Accessibility
    /// Flat, screen-reader friendly rendering with no decorative borders or animations.
    /// Overridden by `CLAUDE_AX_SCREEN_READER` and `--ax-screen-reader`.
    var axScreenReader: Bool?
    /// Follow new output to the bottom (fullscreen rendering only).
    var autoScrollEnabled: Bool?
    /// Ramp mouse-wheel scroll speed during fast scrolls (fullscreen rendering only).
    var wheelScrollAccelerationEnabled: Bool?
    /// Emit OSC 9;4 progress sequences during long operations.
    var terminalProgressBarEnabled: Bool?
    /// Stamp each message with its arrival time.
    var showMessageTimestamps: Bool?
    /// Inverted: `true` turns off syntax highlighting in diffs.
    var syntaxHighlightingDisabled: Bool?
    /// Hide the built-in `-- INSERT --` / `-- VISUAL --` indicator — for status lines
    /// that render `vim.mode` themselves.
    /// Vim INSERT-mode key-sequence remaps, e.g. `{"jj": "<Esc>"}`. Keys are exactly two
    /// printable characters; `<Esc>` is the only supported target. Needs `editorMode: "vim"`.
    var vimInsertModeRemaps: [String: String]?
    /// Underline misspelled words in the prompt input, using a spell checker the user
    /// installs (aspell / hunspell / ispell). Nested object, default disabled.
    var spellcheck: SpellcheckConfig?

    // Model & Performance
    var fastMode: Bool?
    var fastModePerSessionOptIn: Bool?
    var availableModels: [String]?
    /// Extends the `availableModels` allowlist to the Default model selection: if the
    /// tier default isn't allowed, Default resolves to the first allowed entry.
    var enforceAvailableModels: Bool?
    /// Model backing the server-side advisor tool.
    var advisorModel: String?
    /// Fallback chain tried in order when the primary model is overloaded or errors.
    /// Claude Code caps the chain at 3 models and also accepts a bare string,
    /// which we normalize to a one-element array on decode.
    var fallbackModel: [String]?
    /// Prompt cache lifetime for the main conversation: `5m` or `1h`. Default unset ==
    /// automatic (1h on a subscription within limits, 5m on API key/Bedrock/Vertex/Foundry).
    var promptCacheTtl: String?

    // Memory
    var autoMemoryEnabled: Bool?
    var autoMemoryDirectory: String?

    // Voice
    var voiceEnabled: Bool?

    // Updates
    var autoUpdatesChannel: String?

    // Notifications
    var preferredNotifChannel: String?

    // Data
    var cleanupPeriodDays: Int?

    // Attribution
    var attribution: AttributionConfig?
    var prUrlTemplate: String?

    // Teams
    var teammateMode: String?

    // Agent View / Background Agents
    /// Inverted: `true` disables `claude agents`, `--bg`, `/background` and the daemon.
    /// Equivalent to `CLAUDE_CODE_DISABLE_AGENT_VIEW=1`.
    var disableAgentView: Bool?
    /// Custom per-subagent status line shown in the agent panel; receives row context
    /// as JSON on stdin.
    var subagentStatusLine: CommandScriptConfig?

    // Remote Control
    /// Inverted: `true` disables Remote Control entirely (claude.ai/code, `--rc`,
    /// auto-start and the in-session toggle).
    var disableRemoteControl: Bool?
    /// Start the Remote Control bridge automatically each session.
    var remoteControlAtStartup: Bool?
    /// Let Claude push proactive mobile notifications while Remote Control is connected.
    var agentPushNotifEnabled: Bool?
    /// How inbound `SendMessage` peer messages are handled: `accept` delivers them,
    /// `hold` parks them for review, `refuse` opts this session out. Default unset ==
    /// mode parity (auto-deliver only when the sender's permission-mode class matches).
    var crossSessionInbound: String?
    /// How long a dialog forwarded to Remote Control or an SDK host stays parked before
    /// resolving to its safe no-action default. One of `60s`, `5m`, `10m`, `never`.
    var dialogExpiry: String?

    // Artifact
    /// Per-user opt-in. Unset defaults to enabled once the feature is available.
    var enableArtifact: Bool?
    /// Inverted kill switch, also settable via `CLAUDE_CODE_DISABLE_ARTIFACT`.
    var disableArtifact: Bool?

    // Enterprise / Managed
    var pluginSuggestionMarketplaces: [String]?
    var allowAllClaudeAiMcps: Bool?
    /// Inverted: `true` stops claude.ai MCP cloud connectors being auto-fetched.
    var disableClaudeAiConnectors: Bool?
    /// Managed-org opt-in for channel notifications (MCP servers with the
    /// `claude/channel` capability pushing inbound messages).
    var channelsEnabled: Bool?
    /// Enterprise allowlist of usable MCP servers. `nil` == all allowed;
    /// an empty array == none allowed. The denylist wins on conflict.
    var allowedMcpServers: [String]?
    /// Enterprise strict list of permitted marketplace sources. Checked before download.
    var strictKnownMarketplaces: [String]?
    /// Enterprise blocklist of marketplace sources. Checked before download.
    var blockedMarketplaces: [String]?
    /// Inverted: `true` (in managed settings) rejects `--plugin-dir`, `--plugin-url`,
    /// `--agents` and non-SDK `--mcp-config` at startup.
    var disableSideloadFlags: Bool?
    /// Inverted: `true` replaces inline shell execution in skills and custom slash
    /// commands with a placeholder instead of running it.
    var disableSkillShellExecution: Bool?
    /// Set to `"disable"` to prevent `claude-cli://` protocol handler registration.
    var disableDeepLinkRegistration: String?

    // Auto Mode
    var disableAutoMode: String?
    var autoMode: AutoModeConfig?

    // Hooks kill switch
    var disableAllHooks: Bool?

    // CLAUDE.md excludes
    var claudeMdExcludes: [String]?

    // Sandbox (nested config)
    var sandbox: SandboxConfig?

    // Worktree
    var worktree: WorktreeConfig?


    // Spinner
    var spinnerTipsEnabled: Bool?
    var spinnerVerbsMode: String?
    var spinnerVerbs: [String]?
    var spinnerTipsOverride: SpinnerTipsOverride?

    // Status Line (nested object)
    var statusLine: StatusLineConfig?
    // Legacy flat field — kept for backward compat
    var statusLineCommand: String?
}

// MARK: - Tolerant Codable for ClaudeSettings

extension ClaudeSettings: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apiKeyHelper = try? c.decodeIfPresent(String.self, forKey: .apiKeyHelper)
        // Claude Code tolerates non-string env values (numbers, booleans); show them as strings
        // instead of discarding the whole map. Writes are per-key, so nothing is rewritten.
        if let strict = (try? c.decodeIfPresent([String: String].self, forKey: .env)) ?? nil {
            env = strict
        } else if let loose = (try? c.decodeIfPresent([String: JSONValue].self, forKey: .env)) ?? nil {
            env = loose.reduce(into: [:]) { result, pair in
                switch pair.value {
                case .string(let v): result[pair.key] = v
                case .int(let v): result[pair.key] = String(v)
                case .double(let v): result[pair.key] = String(v)
                case .bool(let v): result[pair.key] = v ? "true" : "false"
                default: break
                }
            }
        }
        permissions = (try? c.decodeIfPresent(PermissionsConfig.self, forKey: .permissions)) ?? PermissionsConfig()
        model = (try? c.decodeIfPresent(String.self, forKey: .model)) ?? ""
        hooks = try? c.decodeIfPresent(HooksConfig.self, forKey: .hooks)
        skipWebFetchPreflight = try? c.decodeIfPresent(Bool.self, forKey: .skipWebFetchPreflight)
        alwaysThinkingEnabled = try? c.decodeIfPresent(Bool.self, forKey: .alwaysThinkingEnabled)
        skipDangerousModePermissionPrompt = try? c.decodeIfPresent(Bool.self, forKey: .skipDangerousModePermissionPrompt)
        mainBranch = try? c.decodeIfPresent(String.self, forKey: .mainBranch)
        preferredGitApp = try? c.decodeIfPresent(GitAppPreference.self, forKey: .preferredGitApp)
        customGitAppPath = try? c.decodeIfPresent(String.self, forKey: .customGitAppPath)
        theme = try? c.decodeIfPresent(String.self, forKey: .theme)
        language = try? c.decodeIfPresent(String.self, forKey: .language)
        effortLevel = try? c.decodeIfPresent(String.self, forKey: .effortLevel)
        disableWorkflows = try? c.decodeIfPresent(Bool.self, forKey: .disableWorkflows)
        workflowKeywordTriggerEnabled = try? c.decodeIfPresent(Bool.self, forKey: .workflowKeywordTriggerEnabled)
        outputStyle = try? c.decodeIfPresent(String.self, forKey: .outputStyle)
        verbose = try? c.decodeIfPresent(Bool.self, forKey: .verbose)
        prefersReducedMotion = try? c.decodeIfPresent(Bool.self, forKey: .prefersReducedMotion)
        skillOverrides = try? c.decodeIfPresent([String: String].self, forKey: .skillOverrides)
        disableBundledSkills = try? c.decodeIfPresent(Bool.self, forKey: .disableBundledSkills)
        workflowSizeGuideline = try? c.decodeIfPresent(String.self, forKey: .workflowSizeGuideline)
        showTurnDuration = try? c.decodeIfPresent(Bool.self, forKey: .showTurnDuration)
        respectGitignore = try? c.decodeIfPresent(Bool.self, forKey: .respectGitignore)
        autoCompactEnabled = try? c.decodeIfPresent(Bool.self, forKey: .autoCompactEnabled)
        plansDirectory = try? c.decodeIfPresent(String.self, forKey: .plansDirectory)
        includeGitInstructions = try? c.decodeIfPresent(Bool.self, forKey: .includeGitInstructions)
        showThinkingSummaries = try? c.decodeIfPresent(Bool.self, forKey: .showThinkingSummaries)
        showClearContextOnPlanAccept = try? c.decodeIfPresent(Bool.self, forKey: .showClearContextOnPlanAccept)
        defaultShell = try? c.decodeIfPresent(String.self, forKey: .defaultShell)
        autoCompactWindow = try? c.decodeIfPresent(Int.self, forKey: .autoCompactWindow)
        precomputeCompactionEnabled = try? c.decodeIfPresent(Bool.self, forKey: .precomputeCompactionEnabled)
        todoFeatureEnabled = try? c.decodeIfPresent(Bool.self, forKey: .todoFeatureEnabled)
        askUserQuestionTimeout = try? c.decodeIfPresent(String.self, forKey: .askUserQuestionTimeout)
        awaySummaryEnabled = try? c.decodeIfPresent(Bool.self, forKey: .awaySummaryEnabled)
        promptSuggestionEnabled = try? c.decodeIfPresent(Bool.self, forKey: .promptSuggestionEnabled)
        emojiCompletionEnabled = try? c.decodeIfPresent(Bool.self, forKey: .emojiCompletionEnabled)
        fileCheckpointingEnabled = try? c.decodeIfPresent(Bool.self, forKey: .fileCheckpointingEnabled)
        feedbackSurveyRate = try? c.decodeIfPresent(Double.self, forKey: .feedbackSurveyRate)
        fileSuggestion = try? c.decodeIfPresent(CommandScriptConfig.self, forKey: .fileSuggestion)
        autoContinueAtUsageLimit = try? c.decodeIfPresent(Bool.self, forKey: .autoContinueAtUsageLimit)
        bashOutputMaxChars = try? c.decodeIfPresent(Int.self, forKey: .bashOutputMaxChars)
        idleCompaction = try? c.decodeIfPresent(Bool.self, forKey: .idleCompaction)
        maxProseWidth = try? c.decodeIfPresent(Int.self, forKey: .maxProseWidth)
        bashEditDiffEnabled = try? c.decodeIfPresent(Bool.self, forKey: .bashEditDiffEnabled)
        switchModelsOnFlag = try? c.decodeIfPresent(Bool.self, forKey: .switchModelsOnFlag)
        syncClaudeAiSkills = try? c.decodeIfPresent(Bool.self, forKey: .syncClaudeAiSkills)
        syncClaudeAiPlugins = try? c.decodeIfPresent(Bool.self, forKey: .syncClaudeAiPlugins)
        attributionProject = try? c.decodeIfPresent(String.self, forKey: .attributionProject)
        timeFormat = try? c.decodeIfPresent(String.self, forKey: .timeFormat)
        timeZone = try? c.decodeIfPresent(String.self, forKey: .timeZone)
        axScreenReader = try? c.decodeIfPresent(Bool.self, forKey: .axScreenReader)
        autoScrollEnabled = try? c.decodeIfPresent(Bool.self, forKey: .autoScrollEnabled)
        wheelScrollAccelerationEnabled = try? c.decodeIfPresent(Bool.self, forKey: .wheelScrollAccelerationEnabled)
        terminalProgressBarEnabled = try? c.decodeIfPresent(Bool.self, forKey: .terminalProgressBarEnabled)
        showMessageTimestamps = try? c.decodeIfPresent(Bool.self, forKey: .showMessageTimestamps)
        syntaxHighlightingDisabled = try? c.decodeIfPresent(Bool.self, forKey: .syntaxHighlightingDisabled)
        // Claude Code types the values as `unknown`; only "<Esc>" is a supported target,
        // so drop any non-string values rather than failing the whole settings decode.
        vimInsertModeRemaps = try? c.decodeIfPresent([String: String].self, forKey: .vimInsertModeRemaps)
        spellcheck = try? c.decodeIfPresent(SpellcheckConfig.self, forKey: .spellcheck)
        fastMode = try? c.decodeIfPresent(Bool.self, forKey: .fastMode)
        fastModePerSessionOptIn = try? c.decodeIfPresent(Bool.self, forKey: .fastModePerSessionOptIn)
        availableModels = try? c.decodeIfPresent([String].self, forKey: .availableModels)
        enforceAvailableModels = try? c.decodeIfPresent(Bool.self, forKey: .enforceAvailableModels)
        advisorModel = try? c.decodeIfPresent(String.self, forKey: .advisorModel)
        // Accept both the array form and the legacy single-string form
        if let chain = ((try? c.decodeIfPresent([String].self, forKey: .fallbackModel)) ?? nil) {
            fallbackModel = chain
        } else if let single = ((try? c.decodeIfPresent(String.self, forKey: .fallbackModel)) ?? nil) {
            fallbackModel = [single]
        }
        promptCacheTtl = try? c.decodeIfPresent(String.self, forKey: .promptCacheTtl)
        autoMemoryEnabled = try? c.decodeIfPresent(Bool.self, forKey: .autoMemoryEnabled)
        autoMemoryDirectory = try? c.decodeIfPresent(String.self, forKey: .autoMemoryDirectory)
        voiceEnabled = try? c.decodeIfPresent(Bool.self, forKey: .voiceEnabled)
        autoUpdatesChannel = try? c.decodeIfPresent(String.self, forKey: .autoUpdatesChannel)
        preferredNotifChannel = try? c.decodeIfPresent(String.self, forKey: .preferredNotifChannel)
        cleanupPeriodDays = try? c.decodeIfPresent(Int.self, forKey: .cleanupPeriodDays)
        attribution = try? c.decodeIfPresent(AttributionConfig.self, forKey: .attribution)
        prUrlTemplate = try? c.decodeIfPresent(String.self, forKey: .prUrlTemplate)
        teammateMode = try? c.decodeIfPresent(String.self, forKey: .teammateMode)
        disableAgentView = try? c.decodeIfPresent(Bool.self, forKey: .disableAgentView)
        subagentStatusLine = try? c.decodeIfPresent(CommandScriptConfig.self, forKey: .subagentStatusLine)
        disableRemoteControl = try? c.decodeIfPresent(Bool.self, forKey: .disableRemoteControl)
        remoteControlAtStartup = try? c.decodeIfPresent(Bool.self, forKey: .remoteControlAtStartup)
        agentPushNotifEnabled = try? c.decodeIfPresent(Bool.self, forKey: .agentPushNotifEnabled)
        crossSessionInbound = try? c.decodeIfPresent(String.self, forKey: .crossSessionInbound)
        dialogExpiry = try? c.decodeIfPresent(String.self, forKey: .dialogExpiry)
        enableArtifact = try? c.decodeIfPresent(Bool.self, forKey: .enableArtifact)
        disableArtifact = try? c.decodeIfPresent(Bool.self, forKey: .disableArtifact)
        pluginSuggestionMarketplaces = try? c.decodeIfPresent([String].self, forKey: .pluginSuggestionMarketplaces)
        allowAllClaudeAiMcps = try? c.decodeIfPresent(Bool.self, forKey: .allowAllClaudeAiMcps)
        disableClaudeAiConnectors = try? c.decodeIfPresent(Bool.self, forKey: .disableClaudeAiConnectors)
        channelsEnabled = try? c.decodeIfPresent(Bool.self, forKey: .channelsEnabled)
        allowedMcpServers = try? c.decodeIfPresent([String].self, forKey: .allowedMcpServers)
        strictKnownMarketplaces = try? c.decodeIfPresent([String].self, forKey: .strictKnownMarketplaces)
        blockedMarketplaces = try? c.decodeIfPresent([String].self, forKey: .blockedMarketplaces)
        disableSideloadFlags = try? c.decodeIfPresent(Bool.self, forKey: .disableSideloadFlags)
        disableSkillShellExecution = try? c.decodeIfPresent(Bool.self, forKey: .disableSkillShellExecution)
        disableDeepLinkRegistration = try? c.decodeIfPresent(String.self, forKey: .disableDeepLinkRegistration)
        disableAutoMode = try? c.decodeIfPresent(String.self, forKey: .disableAutoMode)
        autoMode = try? c.decodeIfPresent(AutoModeConfig.self, forKey: .autoMode)
        disableAllHooks = try? c.decodeIfPresent(Bool.self, forKey: .disableAllHooks)
        claudeMdExcludes = try? c.decodeIfPresent([String].self, forKey: .claudeMdExcludes)
        sandbox = try? c.decodeIfPresent(SandboxConfig.self, forKey: .sandbox)
        worktree = try? c.decodeIfPresent(WorktreeConfig.self, forKey: .worktree)
        spinnerTipsEnabled = try? c.decodeIfPresent(Bool.self, forKey: .spinnerTipsEnabled)
        // Claude Code stores `spinnerVerbs` as `{ "mode": "append"|"replace", "verbs": [...] }`.
        // The object's own mode always wins; the flat `spinnerVerbsMode` key written by old
        // builds of this app is only read when `spinnerVerbs` is the old bare array.
        if let flat = (try? c.decodeIfPresent([String].self, forKey: .spinnerVerbs)) ?? nil {
            spinnerVerbs = flat
            spinnerVerbsMode = try? c.decodeIfPresent(String.self, forKey: .spinnerVerbsMode)
        } else if let object = (try? c.decodeIfPresent(SpinnerVerbsObject.self, forKey: .spinnerVerbs)) ?? nil {
            spinnerVerbs = object.verbs
            spinnerVerbsMode = object.mode
        }
        spinnerTipsOverride = try? c.decodeIfPresent(SpinnerTipsOverride.self, forKey: .spinnerTipsOverride)
        statusLine = try? c.decodeIfPresent(StatusLineConfig.self, forKey: .statusLine)
        statusLineCommand = try? c.decodeIfPresent(String.self, forKey: .statusLineCommand)
    }
}

// MARK: - Status Line Config

struct StatusLineConfig: Codable, Equatable {
    var type: String? = "command"
    var command: String?
    var padding: Int?
    var refreshInterval: Int?
    var hideVimModeIndicator: Bool?
}

// MARK: - Spinner Tips Override

struct SpinnerTipsOverride: Codable, Equatable {
    var excludeDefault: Bool?
    /// Claude Code accepts plain strings or `{ "id": "...", "text": "..." }` objects.
    /// Objects are flattened to their text for display; writes use dotted paths and only
    /// touch `tips` when the user edits it, so the original objects are never rewritten.
    var tips: [String]?

    enum CodingKeys: String, CodingKey { case excludeDefault, tips }

    init(excludeDefault: Bool? = nil, tips: [String]? = nil) {
        self.excludeDefault = excludeDefault
        self.tips = tips
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        excludeDefault = try? c.decodeIfPresent(Bool.self, forKey: .excludeDefault)
        if let items = (try? c.decodeIfPresent([JSONValue].self, forKey: .tips)) ?? nil {
            tips = items.compactMap { item in
                switch item {
                case .string(let text): return text
                case .object(let obj): return obj["text"]?.stringValue
                default: return nil
                }
            }
        }
    }
}

/// `spinnerVerbs` object form: `{ "mode": "append" | "replace", "verbs": ["Pondering"] }`.
struct SpinnerVerbsObject: Decodable, Equatable {
    var mode: String?
    var verbs: [String]?

    enum CodingKeys: String, CodingKey { case mode, verbs }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try? c.decodeIfPresent(String.self, forKey: .mode)
        verbs = try? c.decodeIfPresent([String].self, forKey: .verbs)
    }
}

// MARK: - Spellcheck

/// `spellcheck` is an object, not a bool: `{ "enabled": true, "checker": "aspell", … }`.
/// `checker` unset (or "auto") picks the first of aspell/hunspell/ispell found on PATH;
/// `language` is passed to the checker as-is (`aspell --lang`, `hunspell -d`).
struct SpellcheckConfig: Codable, Equatable {
    var enabled: Bool?
    var checker: String?
    var language: String?
}

// MARK: - Command Script Config

/// Shape shared by `fileSuggestion` and `subagentStatusLine`: `{ "type": "command", "command": "…" }`.
struct CommandScriptConfig: Codable, Equatable {
    var type: String? = "command"
    var command: String?
}

// MARK: - Sandbox Config

struct SandboxConfig: Codable, Equatable {
    var enabled: Bool?
    var failIfUnavailable: Bool?
    var autoAllowBashIfSandboxed: Bool?
    var excludedCommands: [String]?
    var allowUnsandboxedCommands: Bool?
    var enableWeakerNestedSandbox: Bool?
    var enableWeakerNetworkIsolation: Bool?
    /// macOS only: let sandboxed commands send Apple Events (and look up the
    /// `appleeventsd` Mach service). Needed for `open`, `osascript` and
    /// browser-based auth flows.
    var allowAppleEvents: Bool?
    var ignoreViolations: [String: [String]]?
    var credentials: SandboxCredentials?
    var filesystem: SandboxFilesystem?
    var network: SandboxNetwork?
}

struct SandboxCredentials: Codable, Equatable {
    var files: [String]?
    var envVars: [String]?
    /// Off unless explicitly enabled — allows plaintext credential injection.
    var allowPlaintextInject: Bool?
}

struct SandboxFilesystem: Codable, Equatable {
    var allowWrite: [String]?
    var denyWrite: [String]?
    var denyRead: [String]?
    var allowRead: [String]?
    /// macOS and Linux/WSL only: skip filesystem isolation entirely while keeping
    /// network and seccomp isolation. Ignored on native Windows.
    var disabled: Bool?
}

struct SandboxNetwork: Codable, Equatable {
    var allowUnixSockets: [String]?
    var allowAllUnixSockets: Bool?
    var allowLocalBinding: Bool?
    var allowedDomains: [String]?
    /// Always blocked, even when matched by `allowedDomains`. Same wildcard syntax.
    var deniedDomains: [String]?
    /// When true, hosts outside `allowedDomains` are denied deterministically
    /// instead of prompting.
    var strictAllowlist: Bool?
    /// When true (and set in managed settings), only managed `allowedDomains` and
    /// `WebFetch(domain:…)` allow rules are honoured.
    var allowManagedDomainsOnly: Bool?
    var httpProxyPort: Int?
    var socksProxyPort: Int?
}

// MARK: - Worktree Config

struct WorktreeConfig: Codable, Equatable {
    var sparsePaths: [String]?
    var symlinkDirectories: [String]?
    var baseRef: String?
    var bgIsolation: String?
}

// MARK: - Auto Compact


// MARK: - Auto Mode

/// Claude Code's auto-mode classifier rule lists. Include the sentinel `"$defaults"`
/// in any list to extend the built-in rules rather than replace them.
struct AutoModeConfig: Codable, Equatable {
    var allow: [String]?
    var softDeny: [String]?
    var hardDeny: [String]?
    var environment: [String]?
    /// Suspends every Bash/PowerShell allow rule while auto mode is active so all shell
    /// commands go through the classifier — safer, but more classifier round-trips.
    var classifyAllShell: Bool?

    enum CodingKeys: String, CodingKey {
        case allow
        case softDeny = "soft_deny"
        case hardDeny = "hard_deny"
        case environment
        case classifyAllShell
    }
}

// MARK: - Attribution

struct AttributionConfig: Codable, Equatable {
    /// Claude Code also accepts a bare Bool (`"attribution": false`); that form lands here
    /// and is re-encoded as a Bool as long as no other field is set.
    var enabled: Bool?
    var commit: String?
    var pr: String?
    /// Whether to append the claude.ai session link to commits and PRs created from
    /// web or Remote Control sessions. Default unset == true; `false` omits the
    /// `Claude-Session` trailer and the PR-body link.
    var sessionUrl: Bool?

    enum CodingKeys: String, CodingKey { case commit, pr, sessionUrl }

    init(commit: String? = nil, pr: String? = nil, sessionUrl: Bool? = nil) {
        self.commit = commit
        self.pr = pr
        self.sessionUrl = sessionUrl
    }

    init(from decoder: Decoder) throws {
        if let flag = try? decoder.singleValueContainer().decode(Bool.self) {
            enabled = flag
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        commit = try? c.decodeIfPresent(String.self, forKey: .commit)
        pr = try? c.decodeIfPresent(String.self, forKey: .pr)
        sessionUrl = try? c.decodeIfPresent(Bool.self, forKey: .sessionUrl)
    }

    func encode(to encoder: Encoder) throws {
        if let enabled, commit == nil, pr == nil, sessionUrl == nil {
            var single = encoder.singleValueContainer()
            try single.encode(enabled)
            return
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(commit, forKey: .commit)
        try c.encodeIfPresent(pr, forKey: .pr)
        try c.encodeIfPresent(sessionUrl, forKey: .sessionUrl)
    }
}

// MARK: - Permissions

struct PermissionsConfig: Codable, Equatable {
    var allow: [String]?
    var deny: [String]?
    var ask: [String]?
    var defaultMode: String?
    var additionalDirectories: [String]?
    var disableBypassPermissionsMode: String?
    var skipDangerousModePermissionPrompt: Bool?
}

// MARK: - Hooks

struct HooksConfig: Codable, Equatable {
    var PreToolUse: [HookGroup]?
    var PostToolUse: [HookGroup]?
    var PrePromptSubmit: [HookGroup]?
    var PostPromptSubmit: [HookGroup]?
    var MessageDisplay: [HookGroup]?
    var PostToolUseFailure: [HookGroup]?
    var PermissionRequest: [HookGroup]?
    var Notification: [HookGroup]?
    var Stop: [HookGroup]?
    var SubagentStart: [HookGroup]?
    var SubagentStop: [HookGroup]?
    var PreCompact: [HookGroup]?
    var PostCompact: [HookGroup]?
    var Elicitation: [HookGroup]?
    var ElicitationResult: [HookGroup]?
    var TeammateIdle: [HookGroup]?
    var TaskCompleted: [HookGroup]?
    var Setup: [HookGroup]?
    var InstructionsLoaded: [HookGroup]?
    var ConfigChange: [HookGroup]?
    var WorktreeCreate: [HookGroup]?
    var WorktreeRemove: [HookGroup]?
    var SessionStart: [HookGroup]?
    var SessionEnd: [HookGroup]?
    var UserPromptSubmit: [HookGroup]?
    var PermissionDenied: [HookGroup]?
    var PostToolBatch: [HookGroup]?
    var StopFailure: [HookGroup]?
    var UserPromptExpansion: [HookGroup]?
    var TaskCreated: [HookGroup]?
    var CwdChanged: [HookGroup]?
    var FileChanged: [HookGroup]?
    var DirectoryAdded: [HookGroup]?
    var PreModelSwitch: [HookGroup]?
    var PostModelSwitch: [HookGroup]?

    // Tolerant decoder: unknown hook types are silently ignored instead of failing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        func decode(_ key: String) -> [HookGroup]? {
            guard let k = DynamicCodingKey(stringValue: key) else { return nil }
            return try? container.decodeIfPresent([HookGroup].self, forKey: k)
        }
        PreToolUse = decode("PreToolUse")
        PostToolUse = decode("PostToolUse")
        PrePromptSubmit = decode("PrePromptSubmit")
        PostPromptSubmit = decode("PostPromptSubmit")
        MessageDisplay = decode("MessageDisplay")
        PostToolUseFailure = decode("PostToolUseFailure")
        PermissionRequest = decode("PermissionRequest")
        Notification = decode("Notification")
        Stop = decode("Stop")
        SubagentStart = decode("SubagentStart")
        SubagentStop = decode("SubagentStop")
        PreCompact = decode("PreCompact")
        PostCompact = decode("PostCompact")
        Elicitation = decode("Elicitation")
        ElicitationResult = decode("ElicitationResult")
        TeammateIdle = decode("TeammateIdle")
        TaskCompleted = decode("TaskCompleted")
        Setup = decode("Setup")
        InstructionsLoaded = decode("InstructionsLoaded")
        ConfigChange = decode("ConfigChange")
        WorktreeCreate = decode("WorktreeCreate")
        WorktreeRemove = decode("WorktreeRemove")
        SessionStart = decode("SessionStart")
        SessionEnd = decode("SessionEnd")
        UserPromptSubmit = decode("UserPromptSubmit")
        PermissionDenied = decode("PermissionDenied")
        PostToolBatch = decode("PostToolBatch")
        StopFailure = decode("StopFailure")
        UserPromptExpansion = decode("UserPromptExpansion")
        TaskCreated = decode("TaskCreated")
        CwdChanged = decode("CwdChanged")
        FileChanged = decode("FileChanged")
        DirectoryAdded = decode("DirectoryAdded")
        PreModelSwitch = decode("PreModelSwitch")
        PostModelSwitch = decode("PostModelSwitch")
    }

    init() {}
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

struct HookGroup: Codable, Equatable, Identifiable {
    var id = UUID()
    /// The CLI schema is `matcher: string` (a tool-name regex such as "Bash|Edit").
    var matcherString: String?
    var hooks: [HookDefinition]
    /// Group-level keys this app does not model, kept verbatim.
    var extra: [String: JSONValue] = [:]

    init(matcherString: String?, hooks: [HookDefinition] = []) {
        self.matcherString = matcherString
        self.hooks = hooks
    }

    init(from decoder: Decoder) throws {
        let all = try decoder.singleValueContainer().decode([String: JSONValue].self)
        if let str = all["matcher"]?.stringValue {
            matcherString = str
        } else if case .object(let legacy)? = all["matcher"] {
            // Older builds of this app wrote {"tool": ..., "pattern": ...}, which the CLI rejects.
            // The matcher is a tool-name regex, so only the tool survives; `tool(pattern)` is
            // permission-rule syntax and belongs in a hook's `if` field instead.
            matcherString = legacy["tool"]?.stringValue
        }
        if case .array(let items)? = all["hooks"] {
            hooks = items.compactMap { item in
                guard let data = try? JSONEncoder().encode(item) else { return nil }
                return try? JSONDecoder().decode(HookDefinition.self, from: data)
            }
        } else {
            hooks = []
        }
        extra = all.filter { $0.key != "matcher" && $0.key != "hooks" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONValue.DynamicKey.self)
        for (key, value) in extra {
            try container.encode(value, forKey: JSONValue.DynamicKey(key))
        }
        try container.encodeIfPresent(matcherString, forKey: JSONValue.DynamicKey("matcher"))
        try container.encode(hooks, forKey: JSONValue.DynamicKey("hooks"))
    }
}

struct HookDefinition: Codable, Equatable, Identifiable {
    var id = UUID()
    var type: String = "command"
    var command: String?
    var args: [String]?
    var prompt: String?
    var agent: String?
    var url: String?
    var ifCondition: String?
    /// Seconds. The CLI accepts fractional values (1.5), so this is a Double; whole
    /// numbers are written back as integers.
    var timeout: Double?
    var continueOnBlock: Bool?
    /// Every key this app does not model (async, once, shell, headers, model, onFailure,
    /// statusMessage, asyncRewake, cloud, and for `mcp_tool`: server/tool/input), plus any
    /// modeled key whose value had an unexpected type. Written back untouched.
    var extra: [String: JSONValue] = [:]

    enum CodingKeys: String, CodingKey {
        case type, command, args, prompt, agent, url, timeout, continueOnBlock
        case ifCondition = "if"
    }

    init(type: String = "command", command: String? = nil, args: [String]? = nil, prompt: String? = nil, agent: String? = nil, url: String? = nil, ifCondition: String? = nil, timeout: Double? = nil, continueOnBlock: Bool? = nil) {
        self.type = type
        self.command = command
        self.args = args
        self.prompt = prompt
        self.agent = agent
        self.url = url
        self.ifCondition = ifCondition
        self.timeout = timeout
        self.continueOnBlock = continueOnBlock
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var leftovers = try decoder.singleValueContainer().decode([String: JSONValue].self)

        func take<T: Decodable>(_ key: CodingKeys, as _: T.Type) -> T? {
            guard let value = (try? container.decodeIfPresent(T.self, forKey: key)) ?? nil else { return nil }
            leftovers.removeValue(forKey: key.stringValue)
            return value
        }
        type = take(.type, as: String.self) ?? "command"
        command = take(.command, as: String.self)
        args = take(.args, as: [String].self)
        prompt = take(.prompt, as: String.self)
        agent = take(.agent, as: String.self)
        url = take(.url, as: String.self)
        ifCondition = take(.ifCondition, as: String.self)
        timeout = take(.timeout, as: Double.self)
        continueOnBlock = take(.continueOnBlock, as: Bool.self)
        extra = leftovers
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: JSONValue.DynamicKey.self)
        for (key, value) in extra {
            try container.encode(value, forKey: JSONValue.DynamicKey(key))
        }
        try container.encode(type, forKey: JSONValue.DynamicKey("type"))
        try container.encodeIfPresent(command, forKey: JSONValue.DynamicKey("command"))
        try container.encodeIfPresent(args, forKey: JSONValue.DynamicKey("args"))
        try container.encodeIfPresent(prompt, forKey: JSONValue.DynamicKey("prompt"))
        try container.encodeIfPresent(agent, forKey: JSONValue.DynamicKey("agent"))
        try container.encodeIfPresent(url, forKey: JSONValue.DynamicKey("url"))
        try container.encodeIfPresent(ifCondition, forKey: JSONValue.DynamicKey("if"))
        if let timeout {
            if timeout == timeout.rounded(), abs(timeout) < 1e15 {
                try container.encode(Int(timeout), forKey: JSONValue.DynamicKey("timeout"))
            } else {
                try container.encode(timeout, forKey: JSONValue.DynamicKey("timeout"))
            }
        }
        try container.encodeIfPresent(continueOnBlock, forKey: JSONValue.DynamicKey("continueOnBlock"))
    }
}

// MARK: - Git App Preference

enum GitAppPreference: String, Codable, CaseIterable, Identifiable {
    case githubDesktop = "GitHub Desktop"
    case fork = "Fork"
    case tower = "Tower"
    case sourcetree = "Sourcetree"
    case gitKraken = "GitKraken"
    case custom = "Custom"

    var id: String { rawValue }

    var bundleIdentifier: String? {
        switch self {
        case .githubDesktop: return "com.github.GitHubClient"
        case .fork: return "com.dan.Fork"
        case .tower: return "com.fournova.Tower3"
        case .sourcetree: return "com.torusknot.SourceTreeNotMAS"
        case .gitKraken: return "com.axosoft.gitkraken"
        case .custom: return nil
        }
    }

    var icon: String {
        switch self {
        case .githubDesktop: return "desktopcomputer"
        case .fork: return "tuningfork"
        case .tower: return "building.2"
        case .sourcetree: return "tree"
        case .gitKraken: return "octagon"
        case .custom: return "app.badge"
        }
    }
}
