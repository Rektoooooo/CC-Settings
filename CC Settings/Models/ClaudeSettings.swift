import Foundation

struct ClaudeSettings: Codable, Equatable {
    var apiKeyHelper: String?
    var env: [String: String] = [:]
    var permissions: PermissionsConfig = PermissionsConfig()
    var model: String = "sonnet"
    var hooks: HooksConfig?
    var skipWebFetchPreflight: Bool?
    var alwaysThinkingEnabled: Bool?
    var thinkingBudgetTokens: Int?
    var mainBranch: String?
    var preferredGitApp: GitAppPreference?
    var customGitAppPath: String?

    // Appearance & Output
    var theme: String?
    var language: String?
    var effortLevel: String?
    var outputStyle: String?
    var verbose: Bool?
    var prefersReducedMotion: Bool?

    // Behavior
    var showTurnDuration: Bool?
    var respectGitignore: Bool?
    var autoCompact: AutoCompactConfig?
    var plansDirectory: String?
    var includeGitInstructions: Bool?
    var showThinkingSummaries: Bool?
    var showClearContextOnPlanAccept: Bool?
    var defaultShell: String?

    // Model & Performance
    var fastMode: Bool?
    var fastModePerSessionOptIn: Bool?
    var availableModels: [String]?

    // Memory
    var autoMemoryEnabled: Bool?
    var autoMemoryDirectory: String?

    // Voice
    var voiceEnabled: Bool?

    // Updates
    var autoUpdates: Bool?
    var autoUpdatesChannel: String?

    // Notifications
    var preferredNotifChannel: String?

    // Data
    var cleanupPeriodDays: Int?

    // Attribution
    var attribution: AttributionConfig?

    // Teams
    var teammateMode: String?

    // Auto Mode
    var disableAutoMode: String?

    // Hooks kill switch
    var disableAllHooks: Bool?

    // CLAUDE.md excludes
    var claudeMdExcludes: [String]?

    // Sandbox (nested config)
    var sandbox: SandboxConfig?

    // Worktree
    var worktree: WorktreeConfig?

    // Legacy flat sandbox fields (kept for backward compat during migration)
    var enableWeakerSandbox: Bool?
    var unsandboxedCommands: [String]?
    var allowLocalBinding: Bool?
    var allowAllUnixSockets: Bool?
    var allowedDomains: [String]?

    // Spinner
    var spinnerTipsEnabled: Bool?
    var spinnerVerbsMode: String?
    var spinnerVerbs: [String]?
    var customTips: [String]?
    var excludeDefaultTips: Bool?
    var spinnerTipsOverride: SpinnerTipsOverride?

    // Status Line (nested object)
    var statusLine: StatusLineConfig?
    // Legacy flat field — kept for backward compat
    var statusLineCommand: String?
}

// MARK: - Status Line Config

struct StatusLineConfig: Codable, Equatable {
    var type: String? = "command"
    var command: String?
    var padding: Int?
}

// MARK: - Spinner Tips Override

struct SpinnerTipsOverride: Codable, Equatable {
    var excludeDefault: Bool?
    var tips: [String]?
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
    var ignoreViolations: [String: [String]]?
    var filesystem: SandboxFilesystem?
    var network: SandboxNetwork?
}

struct SandboxFilesystem: Codable, Equatable {
    var allowWrite: [String]?
    var denyWrite: [String]?
    var denyRead: [String]?
    var allowRead: [String]?
}

struct SandboxNetwork: Codable, Equatable {
    var allowUnixSockets: [String]?
    var allowAllUnixSockets: Bool?
    var allowLocalBinding: Bool?
    var allowedDomains: [String]?
    var httpProxyPort: Int?
    var socksProxyPort: Int?
}

// MARK: - Worktree Config

struct WorktreeConfig: Codable, Equatable {
    var sparsePaths: [String]?
    var symlinkDirectories: [String]?
}

// MARK: - Auto Compact

struct AutoCompactConfig: Codable, Equatable {
    var customInstructions: String?
}

// MARK: - Attribution

struct AttributionConfig: Codable, Equatable {
    var commit: String?
    var pr: String?
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
    var matcher: HookMatcher?
    var hooks: [HookDefinition]

    enum CodingKeys: String, CodingKey {
        case matcher, hooks
    }

    init(matcher: HookMatcher? = nil, hooks: [HookDefinition] = []) {
        self.matcher = matcher
        self.hooks = hooks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matcher = try container.decodeIfPresent(HookMatcher.self, forKey: .matcher)
        hooks = try container.decode([HookDefinition].self, forKey: .hooks)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(matcher, forKey: .matcher)
        try container.encode(hooks, forKey: .hooks)
    }
}

struct HookMatcher: Codable, Equatable {
    var tool: String?
    var pattern: String?
}

struct HookDefinition: Codable, Equatable, Identifiable {
    var id = UUID()
    var type: String = "command"
    var command: String?
    var prompt: String?
    var agent: String?
    var url: String?
    var ifCondition: String?

    enum CodingKeys: String, CodingKey {
        case type, command, prompt, agent, url
        case ifCondition = "if"
    }

    init(type: String = "command", command: String? = nil, prompt: String? = nil, agent: String? = nil, url: String? = nil, ifCondition: String? = nil) {
        self.type = type
        self.command = command
        self.prompt = prompt
        self.agent = agent
        self.url = url
        self.ifCondition = ifCondition
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        agent = try container.decodeIfPresent(String.self, forKey: .agent)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        ifCondition = try container.decodeIfPresent(String.self, forKey: .ifCondition)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(prompt, forKey: .prompt)
        try container.encodeIfPresent(agent, forKey: .agent)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(ifCondition, forKey: .ifCondition)
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
