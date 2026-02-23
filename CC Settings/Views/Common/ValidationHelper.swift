import Foundation

enum ValidationResult {
    case success
    case failure(String)

    var isValid: Bool {
        if case .success = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .failure(let msg) = self { return msg }
        return nil
    }
}

struct ValidationHelper {
    static func validateEnvVarKey(_ key: String) -> ValidationResult {
        let pattern = "^[A-Z_][A-Z0-9_]*$"
        guard key.range(of: pattern, options: .regularExpression) != nil else {
            return .failure("Key must contain only uppercase letters, numbers, and underscores, and start with a letter or underscore")
        }
        return .success
    }

    static func validateUniqueKey(_ key: String, in keys: [String], excluding: String? = nil) -> ValidationResult {
        let otherKeys = keys.filter { $0 != excluding }
        if otherKeys.contains(key) {
            return .failure("Duplicate key: \(key)")
        }
        return .success
    }

    static func validateFilePath(_ path: String) -> ValidationResult {
        guard path.hasPrefix("/") || path.hasPrefix("~") else {
            return .failure("Path must start with / or ~")
        }
        return .success
    }

    static func validateGlobPattern(_ pattern: String) -> ValidationResult {
        var bracketDepth = 0
        var braceDepth = 0
        for char in pattern {
            switch char {
            case "[": bracketDepth += 1
            case "]": bracketDepth -= 1
            case "{": braceDepth += 1
            case "}": braceDepth -= 1
            default: break
            }
            if bracketDepth < 0 || braceDepth < 0 {
                return .failure("Unbalanced brackets or braces")
            }
        }
        if bracketDepth != 0 || braceDepth != 0 {
            return .failure("Unbalanced brackets or braces")
        }
        return .success
    }

    static func validateRegexPattern(_ pattern: String) -> ValidationResult {
        do {
            _ = try NSRegularExpression(pattern: pattern)
            return .success
        } catch {
            return .failure("Invalid regex: \(error.localizedDescription)")
        }
    }

    static func validateCommand(_ command: String) -> ValidationResult {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure("Command cannot be empty")
        }
        return .success
    }

    static func combineResults(_ results: [ValidationResult]) -> ValidationResult {
        for result in results {
            if case .failure = result {
                return result
            }
        }
        return .success
    }

    private static let knownEnvVars: [String: String] = [
        "DISABLE_TELEMETRY": "Disable all telemetry data collection",
        "DISABLE_ERROR_REPORTING": "Disable error reporting to Anthropic",
        "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "Disable non-essential model API calls",
        "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "Disable non-essential network traffic",
        "CLAUDE_CODE_ENABLE_TELEMETRY": "Enable telemetry data collection",
        "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "Enable experimental agent teams feature",
        "DISABLE_AUTOUPDATER": "Disable automatic updates",
        "API_BASE_URL": "Custom API base URL for Claude",
        "HTTP_PROXY": "HTTP proxy server URL",
        "HTTPS_PROXY": "HTTPS proxy server URL",
        "NO_PROXY": "Comma-separated list of hosts to exclude from proxy",
    ]

    static func isKnownEnvVar(_ key: String) -> Bool {
        knownEnvVars.keys.contains(key)
    }

    static func descriptionForEnvVar(_ key: String) -> String? {
        knownEnvVars[key]
    }
}
