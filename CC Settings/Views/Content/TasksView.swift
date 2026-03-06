import SwiftUI

// MARK: - Data Models

private struct TaskSession: Identifiable, Hashable {
    let id: String // UUID directory name
    let projectName: String
    let date: Date
    let highwatermark: Int
    let taskCount: Int
    var tasks: [TaskItem]

    static func == (lhs: TaskSession, rhs: TaskSession) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct TaskItem: Identifiable, Hashable {
    let id: String
    let subject: String
    let description: String
    let status: String
    let activeForm: String

    static func == (lhs: TaskItem, rhs: TaskItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - TasksView

struct TasksView: View {
    @EnvironmentObject var configManager: ConfigurationManager

    @State private var sessions: [TaskSession] = []
    @State private var selectedSessionId: String?
    @State private var searchText = ""
    @State private var isLoading = false

    private static let tasksPath: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/tasks").path
    }()

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var selectedSession: TaskSession? {
        sessions.first { $0.id == selectedSessionId }
    }

    private var filteredSessions: [TaskSession] {
        if searchText.isEmpty { return sessions }
        let query = searchText.lowercased()
        return sessions.filter {
            $0.projectName.lowercased().contains(query) ||
            $0.id.lowercased().contains(query) ||
            $0.tasks.contains { $0.subject.lowercased().contains(query) }
        }
    }

    var body: some View {
        HSplitView {
            sessionColumn
                .frame(minWidth: 220, idealWidth: 300, maxWidth: 380)

            detailColumn
        }
        .onAppear {
            loadSessions()
        }
    }

    // MARK: - Column 1: Sessions

    @ViewBuilder
    private var sessionColumn: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    Text("Tasks")
                        .font(.headline)
                    Spacer()
                    Button {
                        loadSessions()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Reload")
                }
                Text("~/.claude/tasks")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            .padding(12)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Loading tasks...")
                    .font(.caption)
                Spacer()
            } else if filteredSessions.isEmpty {
                Spacer()
                EmptyContentPlaceholder(
                    icon: "checklist",
                    title: sessions.isEmpty ? "No Tasks" : "No Results",
                    subtitle: sessions.isEmpty ? "No task sessions found" : "No sessions match your search"
                )
                Spacer()
            } else {
                List(filteredSessions, selection: $selectedSessionId) { session in
                    TaskSessionRow(
                        session: session,
                        dateFormatter: Self.relativeDateFormatter
                    )
                    .tag(session.id)
                }
                .listStyle(.sidebar)
            }

            Divider()

            HStack {
                Text("\(filteredSessions.count) session\(filteredSessions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Column 2: Detail

    @ViewBuilder
    private var detailColumn: some View {
        if let session = selectedSession {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.projectName)
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(Self.dateFormatter.string(from: session.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if session.highwatermark > 0 {
                                Text("\(session.highwatermark) task\(session.highwatermark == 1 ? "" : "s") created")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()

                    Text(String(session.id.prefix(8)) + "...")
                        .font(.caption2.monospaced())
                        .foregroundColor(.secondary.opacity(0.6))

                    Button {
                        let dir = URL(fileURLWithPath: Self.tasksPath)
                            .appendingPathComponent(session.id)
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassToolbar()

                Divider()

                if session.tasks.isEmpty {
                    Spacer()
                    EmptyContentPlaceholder(
                        icon: "checkmark.circle",
                        title: "No Remaining Tasks",
                        subtitle: session.highwatermark > 0
                            ? "All \(session.highwatermark) tasks were completed and cleaned up"
                            : "This session has no task data"
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(session.tasks) { task in
                                TaskCardView(task: task)
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .frame(minWidth: 400)
        } else {
            EmptyContentPlaceholder(
                icon: "checklist",
                title: "Select a Session",
                subtitle: "Choose a session to view its tasks"
            )
        }
    }

    // MARK: - Data Loading

    private func loadSessions() {
        isLoading = true
        let projects = configManager.loadProjects()

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let baseURL = URL(fileURLWithPath: Self.tasksPath)

            // Build session UUID → project name mapping
            var projectMap: [String: String] = [:]
            for project in projects {
                for session in project.sessions {
                    let uuid = session.filename.replacingOccurrences(of: ".jsonl", with: "")
                    projectMap[uuid] = project.displayName
                }
            }

            guard let dirs = try? fm.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                DispatchQueue.main.async {
                    sessions = []
                    isLoading = false
                }
                return
            }

            var result: [TaskSession] = []
            for dir in dirs {
                guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                    continue
                }
                let sessionId = dir.lastPathComponent
                let modDate = (try? dir.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast

                // Read highwatermark
                var highwatermark = 0
                let hwmURL = dir.appendingPathComponent(".highwatermark")
                if let hwmStr = try? String(contentsOf: hwmURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                   let hwm = Int(hwmStr) {
                    highwatermark = hwm
                }

                // Read task JSON files
                var tasks: [TaskItem] = []
                if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for file in files where file.pathExtension == "json" {
                        if let data = try? Data(contentsOf: file),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let task = TaskItem(
                                id: json["id"] as? String ?? file.deletingPathExtension().lastPathComponent,
                                subject: json["subject"] as? String ?? "Untitled",
                                description: json["description"] as? String ?? "",
                                status: json["status"] as? String ?? "unknown",
                                activeForm: json["activeForm"] as? String ?? ""
                            )
                            tasks.append(task)
                        }
                    }
                }
                tasks.sort { (Int($0.id) ?? 0) < (Int($1.id) ?? 0) }

                let projectName = projectMap[sessionId] ?? "Unknown Project"
                result.append(TaskSession(
                    id: sessionId,
                    projectName: projectName,
                    date: modDate,
                    highwatermark: highwatermark,
                    taskCount: tasks.count,
                    tasks: tasks
                ))
            }

            result.sort { $0.date > $1.date }

            DispatchQueue.main.async {
                sessions = result
                isLoading = false
                if selectedSessionId == nil, let first = result.first {
                    selectedSessionId = first.id
                }
            }
        }
    }
}

// MARK: - Row Views

private struct TaskSessionRow: View {
    let session: TaskSession
    let dateFormatter: RelativeDateTimeFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.projectName)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)
            HStack(spacing: 8) {
                if session.highwatermark > 0 {
                    Label("\(session.highwatermark)", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if session.taskCount > 0 {
                    Label("\(session.taskCount) remaining", systemImage: "circle.dotted")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Label("Done", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Text(dateFormatter.localizedString(for: session.date, relativeTo: Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(String(session.id.prefix(8)) + "...")
                .font(.caption2.monospaced())
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.vertical, 2)
    }
}

private struct TaskCardView: View {
    let task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .frame(width: 16)
                Text(task.subject)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                Text(task.status)
                    .font(.caption)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            if !task.description.isEmpty {
                Text(task.description)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            if !task.activeForm.isEmpty {
                Text(task.activeForm)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(10)
        .glassContainer()
    }

    private var statusIcon: String {
        switch task.status {
        case "completed", "done": return "checkmark.circle.fill"
        case "in_progress", "running": return "play.circle.fill"
        case "pending": return "circle.dotted"
        case "blocked": return "xmark.circle"
        default: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch task.status {
        case "completed", "done": return .green
        case "in_progress", "running": return .blue
        case "pending": return .orange
        case "blocked": return .red
        default: return .secondary
        }
    }
}
