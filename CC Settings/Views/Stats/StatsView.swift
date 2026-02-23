import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @StateObject private var service = StatsService()

    var body: some View {
        VStack(spacing: 0) {
            if let stats = service.stats {
                statsContent(stats)
            } else if service.isRefreshing {
                Spacer()
                ProgressView("Analyzing sessions...")
                    .font(.caption)
                Spacer()
            } else {
                Spacer()
                EmptyContentPlaceholder(
                    icon: "chart.bar.xaxis",
                    title: "No Stats",
                    subtitle: "No session data found"
                )
                Spacer()
            }
        }
        .onAppear {
            service.load(using: configManager)
        }
    }

    @ViewBuilder
    private func statsContent(_ stats: UsageStats) -> some View {
        // Header stat boxes
        HStack(spacing: 16) {
            StatsSummaryBox(icon: "bubble.left.and.bubble.right", iconColor: .themeAccent, value: "\(stats.totalSessions)", title: "Sessions")
            StatsSummaryBox(icon: "folder", iconColor: .orange, value: "\(stats.totalProjects)", title: "Projects")
            StatsSummaryBox(icon: "text.bubble", iconColor: .green, value: formatCount(stats.totalMessages), title: "Messages")
            StatsSummaryBox(icon: "number", iconColor: .purple, value: formatTokens(stats.totalInputTokens + stats.totalOutputTokens), title: "Tokens Used")
            StatsSummaryBox(icon: "internaldrive", iconColor: .red, value: formattedSize(stats.totalStorageBytes), title: "Storage")
            Spacer()
        }
        .padding(16)
        .glassToolbar()

        Divider()

        // Card grid
        ScrollView {
            VStack(spacing: 16) {
                StatsCard(title: "Activity", subtitle: "Last 30 Days") {
                    ActivityChart(dailyActivity: stats.dailyActivity)
                }

                HStack(spacing: 16) {
                    StatsCard(title: "Model Distribution") {
                        ModelDistributionChart(models: stats.modelsUsed)
                    }

                    StatsCard(title: "Top Tools") {
                        TopToolsChart(tools: Array(stats.toolsUsed.prefix(15)))
                    }
                }

                HStack(spacing: 16) {
                    StatsCard(title: "Token Breakdown") {
                        TokenBreakdownView(stats: stats)
                    }

                    StatsCard(title: "Averages") {
                        AveragesView(stats: stats)
                    }
                }

                StatsCard(title: "Top Projects", subtitle: "By Token Usage") {
                    TopProjectsView(projects: stats.topProjects)
                }
            }
            .padding(16)
        }

        Divider()

        // Footer
        HStack {
            Button {
                service.load(using: configManager)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
            .disabled(service.isRefreshing)

            if service.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                Text("Updating...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Last updated: \(stats.cachedAt, style: .relative) ago")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .glassToolbar()
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.1fB", Double(count) / 1_000_000_000)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Stats Card Container

private struct StatsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.subheadline.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassContainer()
    }
}

// MARK: - StatsSummaryBox

private struct StatsSummaryBox: View {
    let icon: String
    let iconColor: Color
    let value: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Activity Chart

private struct ActivityChart: View {
    let dailyActivity: [DailyEntry]

    var body: some View {
        if dailyActivity.allSatisfy({ $0.sessionCount == 0 }) {
            Text("No session activity in the last 30 days")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        } else {
            Chart {
                ForEach(dailyActivity, id: \.date) { entry in
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Sessions", entry.sessionCount)
                    )
                    .foregroundStyle(Color.themeAccent.gradient)
                    .cornerRadius(2)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let count = value.as(Int.self) {
                            Text("\(count)")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                }
            }
            .frame(height: 150)
        }
    }
}

// MARK: - Model Distribution Chart

private struct ModelDistributionChart: View {
    let models: [NamedCount]

    private var displayModels: [NamedCount] {
        Array(models.prefix(8))
    }

    private var chartColors: [Color] {
        [.themeAccent, .orange, .green, .purple, .red, .cyan, .pink, .yellow]
    }

    var body: some View {
        if displayModels.isEmpty {
            Text("No model data")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        } else {
            HStack(alignment: .top, spacing: 16) {
                Chart {
                    ForEach(Array(displayModels.enumerated()), id: \.element.name) { index, entry in
                        SectorMark(
                            angle: .value("Sessions", entry.count),
                            innerRadius: .ratio(0.5),
                            angularInset: 1
                        )
                        .foregroundStyle(chartColors[index % chartColors.count].gradient)
                    }
                }
                .frame(width: 160, height: 160)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(displayModels.enumerated()), id: \.element.name) { index, entry in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(chartColors[index % chartColors.count])
                                .frame(width: 8, height: 8)
                            Text(formatModelName(entry.name))
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("\(entry.count)")
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func formatModelName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "claude-", with: "")
            .replacingOccurrences(of: "-20250", with: " 25-")
            .replacingOccurrences(of: "-20240", with: " 24-")
    }
}

// MARK: - Top Tools Chart

private struct TopToolsChart: View {
    let tools: [NamedCount]

    var body: some View {
        if tools.isEmpty {
            Text("No tool usage data")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        } else {
            Chart {
                ForEach(tools, id: \.name) { entry in
                    BarMark(
                        x: .value("Count", entry.count),
                        y: .value("Tool", entry.name)
                    )
                    .foregroundStyle(Color.green.gradient)
                    .cornerRadius(2)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let count = value.as(Int.self) {
                            Text("\(count)")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                }
            }
            .frame(height: CGFloat(tools.count * 22 + 20))
        }
    }
}

// MARK: - Token Breakdown

private struct TokenBreakdownView: View {
    let stats: UsageStats

    private var totalTokens: Int {
        stats.totalInputTokens + stats.totalOutputTokens
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatLargeNumber(totalTokens))
                    .font(.title.bold().monospaced())
                Text("total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                tokenStat("Input", count: stats.totalInputTokens, color: .themeAccent)
                tokenStat("Output", count: stats.totalOutputTokens, color: .green)
                tokenStat("Cache Read", count: stats.totalCacheReadTokens, color: .orange)
                tokenStat("Cache Creation", count: stats.totalCacheCreationTokens, color: .purple)
            }

            if totalTokens > 0 {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        let inputRatio = CGFloat(stats.totalInputTokens) / CGFloat(totalTokens)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.themeAccent.gradient)
                            .frame(width: max(geo.size.width * inputRatio - 0.5, 0))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green.gradient)
                            .frame(width: max(geo.size.width * (1 - inputRatio) - 0.5, 0))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Input \(percentString(stats.totalInputTokens, of: totalTokens))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Output \(percentString(stats.totalOutputTokens, of: totalTokens))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func tokenStat(_ label: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(formatLargeNumber(count))
                .font(.caption.monospaced())
        }
    }

    private func formatLargeNumber(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func percentString(_ value: Int, of total: Int) -> String {
        guard total > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(value) / Double(total) * 100)
    }
}

// MARK: - Top Projects

private struct TopProjectsView: View {
    let projects: [ProjectEntry]

    private var displayProjects: [ProjectEntry] {
        Array(projects.prefix(10))
    }

    var body: some View {
        if displayProjects.isEmpty {
            Text("No project data")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("Project")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Sessions")
                        .frame(width: 80, alignment: .trailing)
                    Text("Tokens")
                        .frame(width: 100, alignment: .trailing)
                }
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

                ForEach(Array(displayProjects.enumerated()), id: \.offset) { index, project in
                    HStack {
                        Text(project.name)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(project.sessions)")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)
                        Text(formatTokenCount(project.tokens))
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .trailing)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(index % 2 == 0 ? Color.clear : Color.secondary.opacity(0.04))
                }
            }
        }
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Averages

private struct AveragesView: View {
    let stats: UsageStats

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            averageRow(
                label: "Session Duration",
                value: formatDuration(stats.avgSessionDuration),
                icon: "clock",
                color: .themeAccent
            )

            averageRow(
                label: "Messages / Session",
                value: String(format: "%.1f", stats.avgMessagesPerSession),
                icon: "text.bubble",
                color: .green
            )

            if stats.totalSessions > 0 {
                let avgTokens = (stats.totalInputTokens + stats.totalOutputTokens) / max(stats.totalSessions, 1)
                averageRow(
                    label: "Tokens / Session",
                    value: formatAvgTokens(avgTokens),
                    icon: "number",
                    color: .purple
                )
            }
        }
    }

    private func averageRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.body.bold().monospaced())
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        }
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            let remainingSeconds = Int(seconds) % 60
            return "\(minutes)m \(remainingSeconds)s"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }

    private func formatAvgTokens(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
