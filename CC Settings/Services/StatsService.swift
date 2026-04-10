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
    var totalTokens: Int = 0
    var modelsUsed: [NamedCount] = []
    var toolsUsed: [NamedCount] = []
    var dailyActivity: [DailyEntry] = []
    var topProjects: [ProjectEntry] = []
    var avgSessionDuration: TimeInterval = 0
    var avgMessagesPerSession: Double = 0

    // Highlights
    var activeDaysLast30: Int = 0
    var activeDaysTotal: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var longestSessionDuration: TimeInterval = 0
    var longestSessionProject: String?
    var mostActiveDay: String?
    var mostActiveDayCount: Int = 0
    var favoriteModel: String?

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
        let claudeDir = home.appendingPathComponent(".claude")
        let projectsDir = claudeDir.appendingPathComponent("projects")

        var result = UsageStats()
        result.totalProjects = projects.count

        var modelCounts: [String: Int] = [:]
        var toolCounts: [String: Int] = [:]
        var dailyCounts: [String: Int] = [:]
        var projectStats: [ProjectEntry] = []
        var totalDuration: TimeInterval = 0
        var sessionsWithDuration = 0
        var longestDuration: TimeInterval = 0
        var longestProject: String?

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

                for model in scan.metadata.modelsUsed where model != "<synthetic>" {
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
                        if duration > longestDuration {
                            longestDuration = duration
                            longestProject = project.displayName
                        }
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

        // Total tokens
        result.totalTokens = result.totalInputTokens + result.totalOutputTokens

        // Longest session
        result.longestSessionDuration = longestDuration
        result.longestSessionProject = longestProject

        // Active days
        result.activeDaysTotal = dailyCounts.count
        let last30Keys = Set(daily.map { dateFormatter.string(from: $0.date) })
        result.activeDaysLast30 = dailyCounts.keys.filter { last30Keys.contains($0) && dailyCounts[$0]! > 0 }.count

        // Streaks
        var currentStreak = 0
        var bestStreak = 0
        var streak = 0
        for offset in 0..<365 {
            if let date = calendar.date(byAdding: .day, value: -offset, to: today) {
                let key = dateFormatter.string(from: date)
                if dailyCounts[key, default: 0] > 0 {
                    streak += 1
                    bestStreak = max(bestStreak, streak)
                    if offset <= 1 { currentStreak = streak }
                } else {
                    if offset > 1 { streak = 0 }
                }
            }
        }
        result.currentStreak = currentStreak
        result.longestStreak = bestStreak

        // Most active day
        if let best = dailyCounts.max(by: { $0.value < $1.value }) {
            if let date = dateFormatter.date(from: best.key) {
                let displayFmt = DateFormatter()
                displayFmt.dateFormat = "MMM d"
                result.mostActiveDay = displayFmt.string(from: date)
                result.mostActiveDayCount = best.value
            }
        }

        // Favorite model (already filtered <synthetic>)
        if let top = modelCounts.max(by: { $0.value < $1.value }) {
            result.favoriteModel = top.key
        }

        // Calculate total storage for ALL of ~/.claude/, not just session files
        result.totalStorageBytes = Self.totalDirectorySize(at: claudeDir)

        result.cachedAt = Date()

        return result
    }

    /// Recursively calculates the total size of a directory and all its contents.
    nonisolated private static func totalDirectorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }
            total += Int64(size)
        }
        return total
    }
}
