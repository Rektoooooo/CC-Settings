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

    // Experimental: Sandbox
    var enableWeakerSandbox: Bool?
    var unsandboxedCommands: [String]?
    var allowLocalBinding: Bool?
    var allowAllUnixSockets: Bool?
    var allowedDomains: [String]?

    // Experimental: Spinner
    var spinnerTipsEnabled: Bool?
    var spinnerVerbsMode: String?
    var spinnerVerbs: [String]?
    var customTips: [String]?
    var excludeDefaultTips: Bool?

    // Experimental: Status Line
    var statusLineCommand: String?
}

struct AutoCompactConfig: Codable, Equatable {
    var customInstructions: String?
}

struct AttributionConfig: Codable, Equatable {
    var commit: String?
    var pr: String?
}

struct PermissionsConfig: Codable, Equatable {
    var allow: [String]?
    var deny: [String]?
    var ask: [String]?
    var defaultMode: String?
    var additionalDirectories: [String]?
}

struct HooksConfig: Codable, Equatable {
    var PreToolUse: [HookGroup]?
    var PostToolUse: [HookGroup]?
    var PrePromptSubmit: [HookGroup]?
    var PostPromptSubmit: [HookGroup]?
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
    var command: String

    enum CodingKeys: String, CodingKey {
        case type, command
    }

    init(type: String = "command", command: String) {
        self.type = type
        self.command = command
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        command = try container.decode(String.self, forKey: .command)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(command, forKey: .command)
    }
}

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
