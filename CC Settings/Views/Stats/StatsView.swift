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
        // Header
        HStack(spacing: 16) {
            StatsSummaryBox(icon: "bubble.left.and.bubble.right", iconColor: .themeAccent, value: "\(stats.totalSessions)", title: "Sessions")
            StatsSummaryBox(icon: "folder", iconColor: .orange, value: "\(stats.totalProjects)", title: "Projects")
            StatsSummaryBox(icon: "text.bubble", iconColor: .green, value: formatCount(stats.totalMessages), title: "Messages")
            StatsSummaryBox(icon: "number", iconColor: .purple, value: formatTokens(stats.totalInputTokens + stats.totalOutputTokens), title: "Tokens Used")
            StatsSummaryBox(icon: "internaldrive", iconColor: .red, value: formattedSize(stats.totalStorageBytes), title: "Storage")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassToolbar()

        Divider()

        // Dashboard grid — GeometryReader to fill available space
        GeometryReader { geo in
            ScrollView {
                let w = geo.size.width - 24  // 12px padding each side
                let gap: CGFloat = 10

                VStack(spacing: gap) {
                    // Row 1: Activity (2/3) + Token Breakdown (1/3)
                    HStack(alignment: .top, spacing: gap) {
                        StatsCard(title: "ACTIVITY", subtitle: "Last 30 Days") {
                            ActivityChart(dailyActivity: stats.dailyActivity)
                        }
                        .frame(width: w * 0.65)

                        StatsCard(title: "TOKEN BREAKDOWN") {
                            TokenBreakdownView(stats: stats)
                        }
                    }

                    // Row 2: Model (1/3) + Tools (1/3) + Top Projects (1/3)
                    HStack(alignment: .top, spacing: gap) {
                        StatsCard(title: "MODELS") {
                            ModelDistributionChart(models: stats.modelsUsed)
                        }

                        StatsCard(title: "TOP TOOLS") {
                            TopToolsChart(tools: Array(stats.toolsUsed.prefix(12)))
                        }

                        StatsCard(title: "TOP PROJECTS") {
                            TopProjectsView(projects: stats.topProjects, stats: stats)
                        }
                    }
                }
                .padding(12)
            }
        }

        Divider()

        // Footer
        HStack(spacing: 8) {
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
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("Updated \(stats.cachedAt, style: .relative) ago")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

// MARK: - Stats Card

private struct StatsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(title)
                    .font(.caption2.bold())
                    .tracking(0.5)
                    .foregroundColor(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.body)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Activity Chart

private struct ActivityChart: View {
    let dailyActivity: [DailyEntry]
    @State private var hoveredDate: Date?

    private static let tooltipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var body: some View {
        if dailyActivity.allSatisfy({ $0.sessionCount == 0 }) {
            Text("No activity in the last 30 days")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            Chart {
                ForEach(dailyActivity, id: \.date) { entry in
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Sessions", entry.sessionCount)
                    )
                    .foregroundStyle(
                        hoveredDate != nil && Calendar.current.isDate(entry.date, inSameDayAs: hoveredDate!)
                            ? Color.themeAccent.opacity(1.0)
                            : Color.themeAccent.opacity(hoveredDate == nil ? 1.0 : 0.4)
                    )
                    .cornerRadius(2)
                }

                if let hovered = hoveredDate,
                   let entry = dailyActivity.first(where: { Calendar.current.isDate($0.date, inSameDayAs: hovered) }),
                   entry.sessionCount > 0 {
                    RuleMark(x: .value("Date", entry.date, unit: .day))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .font(.caption2)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.2))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisValueLabel {
                        if let count = value.as(Int.self) {
                            Text("\(count)")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.2))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                if let date: Date = proxy.value(atX: location.x) {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        hoveredDate = date
                                    }
                                }
                            case .ended:
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    hoveredDate = nil
                                }
                            }
                        }
                }
            }
            .chartOverlay { proxy in
                if let hovered = hoveredDate,
                   let entry = dailyActivity.first(where: { Calendar.current.isDate($0.date, inSameDayAs: hovered) }),
                   entry.sessionCount > 0 {
                    GeometryReader { geo in
                        if let xPos = proxy.position(forX: entry.date) {
                            let tooltipWidth: CGFloat = 110
                            let clampedX = min(max(xPos - tooltipWidth / 2, 0), geo.size.width - tooltipWidth)

                            VStack(spacing: 2) {
                                Text(Self.tooltipDateFormatter.string(from: entry.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(entry.sessionCount) session\(entry.sessionCount == 1 ? "" : "s")")
                                    .font(.caption2.bold())
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            .frame(width: tooltipWidth)
                            .position(x: clampedX + tooltipWidth / 2, y: 8)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Model Distribution

private struct ModelDistributionChart: View {
    let models: [NamedCount]
    @State private var hoveredModel: String?

    private var displayModels: [NamedCount] {
        Array(models.prefix(6))
    }

    private var totalCount: Int {
        displayModels.reduce(0) { $0 + $1.count }
    }

    private var chartColors: [Color] {
        [.themeAccent, .orange, .green, .purple, .red, .cyan]
    }

    var body: some View {
        if displayModels.isEmpty {
            Text("No model data")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            VStack(spacing: 8) {
                Chart {
                    ForEach(Array(displayModels.enumerated()), id: \.element.name) { index, entry in
                        SectorMark(
                            angle: .value("Sessions", entry.count),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(chartColors[index % chartColors.count].opacity(
                            hoveredModel == nil || hoveredModel == entry.name ? 1.0 : 0.35
                        ))
                    }
                }
                .chartBackground { _ in
                    if let hovered = hoveredModel,
                       let entry = displayModels.first(where: { $0.name == hovered }) {
                        VStack(spacing: 1) {
                            Text(formatPercent(entry.count))
                                .font(.title3.bold().monospaced())
                            Text(formatModelName(entry.name))
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 130)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(displayModels.enumerated()), id: \.element.name) { index, entry in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(chartColors[index % chartColors.count])
                                .frame(width: 6, height: 6)
                            Text(formatModelName(entry.name))
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(entry.count)")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                        }
                        .opacity(hoveredModel == nil || hoveredModel == entry.name ? 1.0 : 0.4)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.12)) {
                                hoveredModel = hovering ? entry.name : nil
                            }
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

    private func formatPercent(_ count: Int) -> String {
        guard totalCount > 0 else { return "0%" }
        let pct = Double(count) / Double(totalCount) * 100
        return String(format: "%.0f%%", pct)
    }
}

// MARK: - Top Tools

private struct TopToolsChart: View {
    let tools: [NamedCount]
    @State private var hoveredTool: String?

    var body: some View {
        if tools.isEmpty {
            Text("No tool data")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            Chart {
                ForEach(tools, id: \.name) { entry in
                    BarMark(
                        x: .value("Count", entry.count),
                        y: .value("Tool", entry.name)
                    )
                    .foregroundStyle(
                        hoveredTool == nil || hoveredTool == entry.name
                            ? Color.green.opacity(1.0)
                            : Color.green.opacity(0.3)
                    )
                    .cornerRadius(2)
                    .annotation(position: .trailing, spacing: 4) {
                        if hoveredTool == entry.name {
                            Text("\(entry.count)")
                                .font(.caption2.bold().monospaced())
                                .foregroundColor(.primary)
                                .transition(.opacity)
                        }
                    }
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
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.2))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                if let tool: String = proxy.value(atY: location.y) {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        hoveredTool = tool
                                    }
                                }
                            case .ended:
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    hoveredTool = nil
                                }
                            }
                        }
                }
            }
            .frame(maxHeight: .infinity)
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
        VStack(alignment: .leading, spacing: 10) {
            // Big total
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatCompact(totalTokens))
                    .font(.title.bold().monospaced())
                Text("tokens")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if totalTokens > 0 {
                // Ratio bar
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
                .frame(height: 6)
            }

            Spacer(minLength: 0)

            // Categories
            VStack(alignment: .leading, spacing: 6) {
                tokenRow("Input", count: stats.totalInputTokens, color: .themeAccent)
                tokenRow("Output", count: stats.totalOutputTokens, color: .green)
                tokenRow("Cache Read", count: stats.totalCacheReadTokens, color: .orange)
                tokenRow("Cache Creation", count: stats.totalCacheCreationTokens, color: .purple)
            }

            Spacer(minLength: 0)

            // Averages inline
            HStack(spacing: 12) {
                miniStat("Avg Duration", value: formatDuration(stats.avgSessionDuration))
                miniStat("Msgs/Session", value: String(format: "%.0f", stats.avgMessagesPerSession))
                if stats.totalSessions > 0 {
                    let avg = (stats.totalInputTokens + stats.totalOutputTokens) / max(stats.totalSessions, 1)
                    miniStat("Tokens/Session", value: formatCompact(avg))
                }
            }
        }
    }

    private func tokenRow(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer(minLength: 4)
            Text(formatNumber(count))
                .font(.caption2.monospaced())
        }
    }

    private func miniStat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.caption2.bold().monospaced())
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    private func formatCompact(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            return String(format: "%.2fB", Double(count) / 1_000_000_000)
        } else if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func formatNumber(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return String(format: "%.0fs", seconds) }
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

// MARK: - Top Projects

private struct TopProjectsView: View {
    let projects: [ProjectEntry]
    let stats: UsageStats

    private var displayProjects: [ProjectEntry] {
        Array(projects.prefix(10))
    }

    var body: some View {
        if displayProjects.isEmpty {
            Text("No project data")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Project")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Sessions")
                        .frame(width: 55, alignment: .trailing)
                    Text("Tokens")
                        .frame(width: 65, alignment: .trailing)
                }
                .font(.system(size: 9).bold())
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.horizontal, 4)
                .padding(.bottom, 3)

                ForEach(Array(displayProjects.enumerated()), id: \.offset) { index, project in
                    HStack {
                        Text(project.name)
                            .font(.caption2)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(project.sessions)")
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                            .frame(width: 55, alignment: .trailing)
                        Text(formatTokenCount(project.tokens))
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                            .frame(width: 65, alignment: .trailing)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(index % 2 == 1 ? Color.secondary.opacity(0.04) : Color.clear)
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
