import SwiftUI
import Charts

// MARK: - CleanupView

struct CleanupView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var projects: [Project] = []
    @State private var selectedProjectIds: Set<String> = []
    @State private var sortOrder: SortOrder = .size
    @State private var filterOption: FilterOption = .all
    @State private var isLoading = false
    @State private var showDeleteAlert = false

    enum SortOrder: String, CaseIterable {
        case size = "Size"
        case lastAccessed = "Last Accessed"
        case sessions = "Sessions"
        case name = "Name"
    }

    enum FilterOption: String, CaseIterable {
        case all = "All"
        case olderThan1Week = "> 1 Week"
        case olderThan1Month = "> 1 Month"
        case olderThan3Months = "> 3 Months"
        case olderThan6Months = "> 6 Months"
        case olderThan1Year = "> 1 Year"

        var cutoffDate: Date? {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .all: return nil
            case .olderThan1Week: return calendar.date(byAdding: .weekOfYear, value: -1, to: now)
            case .olderThan1Month: return calendar.date(byAdding: .month, value: -1, to: now)
            case .olderThan3Months: return calendar.date(byAdding: .month, value: -3, to: now)
            case .olderThan6Months: return calendar.date(byAdding: .month, value: -6, to: now)
            case .olderThan1Year: return calendar.date(byAdding: .year, value: -1, to: now)
            }
        }
    }

    private var totalStorage: Int64 {
        projects.reduce(0) { $0 + $1.totalSize }
    }

    private var totalSessions: Int {
        projects.reduce(0) { $0 + $1.sessions.count }
    }

    private var selectedSize: Int64 {
        projects.filter { selectedProjectIds.contains($0.id) }.reduce(0) { $0 + $1.totalSize }
    }

    private var sortedFilteredProjects: [Project] {
        var filtered = projects

        if let cutoff = filterOption.cutoffDate {
            filtered = filtered.filter { project in
                guard let lastAccessed = project.lastAccessed else { return true }
                return lastAccessed < cutoff
            }
        }

        switch sortOrder {
        case .size:
            filtered.sort { $0.totalSize > $1.totalSize }
        case .lastAccessed:
            filtered.sort { ($0.lastAccessed ?? .distantPast) > ($1.lastAccessed ?? .distantPast) }
        case .sessions:
            filtered.sort { $0.sessions.count > $1.sessions.count }
        case .name:
            filtered.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }

        return filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            HStack(spacing: 16) {
                StatBox(icon: "internaldrive", iconColor: .themeAccent, value: formattedSize(totalStorage), title: "Total Storage")
                StatBox(icon: "folder", iconColor: .orange, value: "\(projects.count)", title: "Projects")
                StatBox(icon: "doc.text", iconColor: .green, value: "\(totalSessions)", title: "Sessions")
                if !selectedProjectIds.isEmpty {
                    StatBox(icon: "checkmark.circle", iconColor: .accentColor, value: formattedSize(selectedSize), title: "Selected (\(selectedProjectIds.count))")
                }
                Spacer()
            }
            .padding(16)
            .glassToolbar()

            Divider()

            // Main area
            HSplitView {
                // Left - Projects list
                VStack(spacing: 0) {
                    // Toolbar
                    HStack(spacing: 12) {
                        Picker("Sort", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .frame(width: 150)

                        Picker("Filter", selection: $filterOption) {
                            ForEach(FilterOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .frame(width: 150)

                        Spacer()

                        Button("Select All") {
                            selectedProjectIds = Set(sortedFilteredProjects.map(\.id))
                        }
                        .controlSize(.small)

                        Button("None") {
                            selectedProjectIds.removeAll()
                        }
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    // Project list
                    if isLoading {
                        Spacer()
                        ProgressView("Loading projects...")
                            .font(.caption)
                        Spacer()
                    } else if sortedFilteredProjects.isEmpty {
                        Spacer()
                        EmptyContentPlaceholder(
                            icon: "folder.badge.questionmark",
                            title: "No Projects",
                            subtitle: projects.isEmpty ? "No projects found" : "No projects match the current filter"
                        )
                        Spacer()
                    } else {
                        List {
                            ForEach(sortedFilteredProjects) { project in
                                CleanupProjectRow(
                                    project: project,
                                    isSelected: selectedProjectIds.contains(project.id),
                                    onToggle: {
                                        if selectedProjectIds.contains(project.id) {
                                            selectedProjectIds.remove(project.id)
                                        } else {
                                            selectedProjectIds.insert(project.id)
                                        }
                                    }
                                )
                                .contextMenu {
                                    Button(selectedProjectIds.contains(project.id) ? "Deselect" : "Select") {
                                        if selectedProjectIds.contains(project.id) {
                                            selectedProjectIds.remove(project.id)
                                        } else {
                                            selectedProjectIds.insert(project.id)
                                        }
                                    }
                                    Button("Show in Finder") {
                                        let home = FileManager.default.homeDirectoryForCurrentUser
                                        let projectDir = home.appendingPathComponent(".claude/projects").appendingPathComponent(project.id)
                                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: projectDir.path)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(minWidth: 400)

                // Right - Stats sidebar
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        StorageChart(projects: projects)

                        Divider()

                        AgeDistributionView(projects: projects)

                        Divider()

                        RecommendationsView(
                            projects: projects,
                            onSelectOld: {
                                let cutoff = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
                                selectedProjectIds = Set(projects.filter { project in
                                    guard let lastAccessed = project.lastAccessed else { return true }
                                    return lastAccessed < cutoff
                                }.map(\.id))
                            },
                            onSelectLargest: {
                                let topFive = projects.sorted { $0.totalSize > $1.totalSize }.prefix(5)
                                selectedProjectIds = Set(topFive.map(\.id))
                            }
                        )
                    }
                    .padding(16)
                }
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 350)
            }

            Divider()

            // Footer
            HStack {
                Button {
                    loadProjects()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)

                Spacer()

                if !selectedProjectIds.isEmpty {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Selected (\(selectedProjectIds.count) - \(formattedSize(selectedSize)))", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .glassToolbar()
        }
        .onAppear {
            loadProjects()
        }
        .alert("Delete Selected Projects", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedProjects()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedProjectIds.count) project\(selectedProjectIds.count == 1 ? "" : "s") (\(formattedSize(selectedSize)))? This cannot be undone.")
        }
    }

    private func loadProjects() {
        isLoading = true
        projects = configManager.loadProjects()
        selectedProjectIds.removeAll()
        isLoading = false
    }

    private func deleteSelectedProjects() {
        let fm = FileManager.default
        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectsDir = home.appendingPathComponent(".claude/projects")

        for id in selectedProjectIds {
            let projectDir = projectsDir.appendingPathComponent(id)
            try? fm.removeItem(at: projectDir)
        }

        selectedProjectIds.removeAll()
        loadProjects()
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - StatBox

private struct StatBox: View {
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

// MARK: - CleanupProjectRow

private struct CleanupProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onToggle: () -> Void

    private var isEmpty: Bool {
        project.sessions.isEmpty && project.totalSize == 0
    }

    private var sizeColor: Color {
        if project.totalSize > 100_000_000 { return .red }
        if project.totalSize > 10_000_000 { return .orange }
        return .primary
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onToggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.displayName)
                    .font(.body)
                    .lineLimit(1)
                Text(project.originalPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .opacity(isEmpty ? 0.5 : 1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(ByteCountFormatter.string(fromByteCount: project.totalSize, countStyle: .file))
                    .font(.caption.monospaced())
                    .foregroundColor(isEmpty ? .secondary : sizeColor)
                HStack(spacing: 6) {
                    Text("\(project.sessions.count) sessions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let date = project.lastAccessed {
                        Text(date, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - StorageChart

private struct StorageChart: View {
    let projects: [Project]

    private var topProjects: [Project] {
        Array(projects.sorted { $0.totalSize > $1.totalSize }.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Storage by Project")
                .font(.subheadline.bold())

            if topProjects.isEmpty {
                Text("No project data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                Chart(topProjects) { project in
                    BarMark(
                        x: .value("Size", project.totalSize),
                        y: .value("Project", project.displayName)
                    )
                    .foregroundStyle(Color.themeAccent.gradient)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let bytes = value.as(Int64.self) {
                                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(topProjects.count * 28 + 40))
            }
        }
    }
}

// MARK: - AgeDistributionView

private struct AgeDistributionView: View {
    let projects: [Project]

    private struct AgeBucket: Identifiable {
        let id: String
        let label: String
        let count: Int
        let color: Color
    }

    private var buckets: [AgeBucket] {
        let calendar = Calendar.current
        let now = Date()
        let oneWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
        let fourWeeks = calendar.date(byAdding: .weekOfYear, value: -4, to: now)!
        let threeMonths = calendar.date(byAdding: .month, value: -3, to: now)!

        var lessThanWeek = 0
        var oneToFourWeeks = 0
        var oneToThreeMonths = 0
        var moreThanThreeMonths = 0

        for project in projects {
            guard let date = project.lastAccessed else {
                moreThanThreeMonths += 1
                continue
            }
            if date > oneWeek {
                lessThanWeek += 1
            } else if date > fourWeeks {
                oneToFourWeeks += 1
            } else if date > threeMonths {
                oneToThreeMonths += 1
            } else {
                moreThanThreeMonths += 1
            }
        }

        return [
            AgeBucket(id: "1", label: "< 1 week", count: lessThanWeek, color: .green),
            AgeBucket(id: "2", label: "1-4 weeks", count: oneToFourWeeks, color: .themeAccent),
            AgeBucket(id: "3", label: "1-3 months", count: oneToThreeMonths, color: .orange),
            AgeBucket(id: "4", label: "> 3 months", count: moreThanThreeMonths, color: .red),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Age Distribution")
                .font(.subheadline.bold())

            ForEach(buckets) { bucket in
                HStack(spacing: 8) {
                    Text(bucket.label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)

                    GeometryReader { geo in
                        let maxCount = buckets.map(\.count).max() ?? 1
                        let width = maxCount > 0 ? (CGFloat(bucket.count) / CGFloat(maxCount)) * geo.size.width : 0
                        RoundedRectangle(cornerRadius: 3)
                            .fill(bucket.color.gradient)
                            .frame(width: max(width, bucket.count > 0 ? 4 : 0), height: geo.size.height)
                    }
                    .frame(height: 16)

                    Text("\(bucket.count)")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - RecommendationsView

private struct RecommendationsView: View {
    let projects: [Project]
    var onSelectOld: () -> Void
    var onSelectLargest: () -> Void

    private var oldProjectCount: Int {
        let cutoff = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        return projects.filter { project in
            guard let date = project.lastAccessed else { return true }
            return date < cutoff
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations")
                .font(.subheadline.bold())

            Button {
                onSelectOld()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clean old projects")
                            .font(.caption.bold())
                        Text("Select \(oldProjectCount) project\(oldProjectCount == 1 ? "" : "s") older than 3 months")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(8)
                .glassContainer()
            }
            .buttonStyle(.plain)

            Button {
                onSelectLargest()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.minus")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clean largest projects")
                            .font(.caption.bold())
                        Text("Select top 5 projects by size")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(8)
                .glassContainer()
            }
            .buttonStyle(.plain)
        }
    }
}
