import Foundation

// MARK: - Codable Stats Model

struct NamedCount: Codable {
    let name: String
    let count: Int
}

struct DailyEntry: Codable {
    let date: Date
    let sessionCount: Int
}

struct ProjectEntry: Codable {
    let name: String
    let sessions: Int
    let tokens: Int
}

struct UsageStats: Codable {
    var totalSessions: Int = 0
    var totalProjects: Int = 0
    var totalMessages: Int = 0
    var totalStorageBytes: Int64 = 0
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCacheReadTokens: Int = 0
    var totalCacheCreationTokens: Int = 0
    var modelsUsed: [NamedCount] = []
    var toolsUsed: [NamedCount] = []
    var dailyActivity: [DailyEntry] = []
    var topProjects: [ProjectEntry] = []
    var avgSessionDuration: TimeInterval = 0
    var avgMessagesPerSession: Double = 0
    var cachedAt: Date = Date()
}

// MARK: - StatsService

@MainActor
final class StatsService: ObservableObject {
    @Published var stats: UsageStats?
    @Published var isRefreshing = false

    nonisolated private static var cacheURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/stats-cache.json")
    }

    func load(using configManager: ConfigurationManager) {
        guard !isRefreshing else { return }

        // Show cached data immediately if available
        if stats == nil {
            stats = Self.loadCacheFromDisk()
        }

        isRefreshing = true

        Task.detached {
            let freshStats = await Self.aggregate(using: configManager)

            await MainActor.run {
                self.stats = freshStats
                self.isRefreshing = false
            }

            Self.saveCacheToDisk(freshStats)
        }
    }

    // MARK: - Cache

    nonisolated private static func loadCacheFromDisk() -> UsageStats? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(UsageStats.self, from: data)
    }

    nonisolated private static func saveCacheToDisk(_ stats: UsageStats) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(stats) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    // MARK: - Aggregation

    nonisolated private static func aggregate(using configManager: ConfigurationManager) async -> UsageStats {
        let projects = await MainActor.run { configManager.loadProjects() }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectsDir = home.appendingPathComponent(".claude/projects")

        var result = UsageStats()
        result.totalProjects = projects.count

        var modelCounts: [String: Int] = [:]
        var toolCounts: [String: Int] = [:]
        var dailyCounts: [String: Int] = [:]
        var projectStats: [ProjectEntry] = []
        var totalDuration: TimeInterval = 0
        var sessionsWithDuration = 0

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for project in projects {
            let projectDir = projectsDir.appendingPathComponent(project.id)
            var projectTokens = 0

            for session in project.sessions {
                result.totalSessions += 1
                result.totalStorageBytes += session.size

                let sessionURL = projectDir.appendingPathComponent(session.filename)
                let scan = SessionParser.scanSession(at: sessionURL)

                result.totalMessages += scan.metadata.messageCount
                result.totalInputTokens += scan.tokens.inputTokens
                result.totalOutputTokens += scan.tokens.outputTokens
                result.totalCacheReadTokens += scan.tokens.cacheReadTokens
                result.totalCacheCreationTokens += scan.tokens.cacheCreationTokens
                projectTokens += scan.tokens.inputTokens + scan.tokens.outputTokens

                for model in scan.metadata.modelsUsed {
                    modelCounts[model, default: 0] += 1
                }
                for tool in scan.metadata.toolsUsed {
                    toolCounts[tool, default: 0] += 1
                }

                if let first = scan.metadata.firstTimestamp {
                    let dayKey = dateFormatter.string(from: first)
                    dailyCounts[dayKey, default: 0] += 1
                }

                if let first = scan.metadata.firstTimestamp, let last = scan.metadata.lastTimestamp {
                    let duration = last.timeIntervalSince(first)
                    if duration > 0 {
                        totalDuration += duration
                        sessionsWithDuration += 1
                    }
                }
            }

            if !project.sessions.isEmpty {
                projectStats.append(ProjectEntry(
                    name: project.displayName,
                    sessions: project.sessions.count,
                    tokens: projectTokens
                ))
            }
        }

        result.modelsUsed = modelCounts
            .map { NamedCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        result.toolsUsed = toolCounts
            .map { NamedCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var daily: [DailyEntry] = []
        for offset in (0..<30).reversed() {
            if let date = calendar.date(byAdding: .day, value: -offset, to: today) {
                let key = dateFormatter.string(from: date)
                daily.append(DailyEntry(date: date, sessionCount: dailyCounts[key] ?? 0))
            }
        }
        result.dailyActivity = daily

        result.topProjects = projectStats.sorted { $0.tokens > $1.tokens }

        if sessionsWithDuration > 0 {
            result.avgSessionDuration = totalDuration / Double(sessionsWithDuration)
        }
        if result.totalSessions > 0 {
            result.avgMessagesPerSession = Double(result.totalMessages) / Double(result.totalSessions)
        }

        result.cachedAt = Date()

        return result
    }
}
