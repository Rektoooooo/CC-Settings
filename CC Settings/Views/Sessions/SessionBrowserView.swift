import SwiftUI

struct SessionBrowserView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var projects: [Project] = []
    @State private var selectedProject: Project?
    @State private var selectedSession: Session?
    @State private var messages: [SessionMessage] = []
    @State private var metadata: SessionMetadata?
    @State private var projectSearchText = ""
    @State private var sessionSearchText = ""
    @State private var messageSearchText = ""
    @State private var isLoadingProjects = false
    @State private var isLoadingMessages = false

    private let projectsBasePath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/projects").path
    }()

    private var filteredProjects: [Project] {
        let filtered = projects.filter { !$0.sessions.isEmpty }
        if projectSearchText.isEmpty { return filtered }
        let query = projectSearchText.lowercased()
        return filtered.filter {
            $0.displayName.lowercased().contains(query) ||
            $0.originalPath.lowercased().contains(query)
        }
    }

    private var sortedSessions: [Session] {
        guard let project = selectedProject else { return [] }
        let sorted = project.sessions.sorted { $0.lastModified > $1.lastModified }
        if sessionSearchText.isEmpty { return sorted }
        let query = sessionSearchText.lowercased()
        return sorted.filter {
            $0.filename.lowercased().contains(query) ||
            Self.sessionDateFormatter.string(from: $0.lastModified).lowercased().contains(query)
        }
    }

    private var filteredMessages: [SessionMessage] {
        if messageSearchText.isEmpty { return messages }
        let query = messageSearchText.lowercased()
        return messages.filter { message in
            message.content.contains { block in
                switch block {
                case .text(let str):
                    return str.lowercased().contains(query)
                case .toolUse(let tool):
                    return tool.name.lowercased().contains(query) ||
                           tool.input.lowercased().contains(query)
                case .toolResult(let result):
                    return result.content.lowercased().contains(query)
                case .thinking(let str):
                    return str.lowercased().contains(query)
                }
            }
        }
    }

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f
    }()

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private static let sessionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HSplitView {
            // Column 1 - Projects
            projectColumn
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 300)

            // Column 2 - Sessions
            sessionColumn
                .frame(minWidth: 200, idealWidth: 280, maxWidth: 350)

            // Column 3 - Messages
            messageColumn
        }
        .onAppear {
            loadProjects()
        }
    }

    // MARK: - Column 1: Projects

    @ViewBuilder
    private var projectColumn: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    Text("Projects")
                        .font(.headline)
                    Spacer()
                    Button {
                        loadProjects()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Reload")
                }
                Text("~/.claude/projects")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            .padding(12)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search projects...", text: $projectSearchText)
                    .textFieldStyle(.plain)
                if !projectSearchText.isEmpty {
                    Button {
                        projectSearchText = ""
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

            // Project list
            if isLoadingProjects {
                Spacer()
                ProgressView("Loading projects...")
                    .font(.caption)
                Spacer()
            } else if filteredProjects.isEmpty {
                Spacer()
                EmptyContentPlaceholder(
                    icon: "folder",
                    title: projects.isEmpty ? "No Projects" : "No Results",
                    subtitle: projects.isEmpty ? "No projects with sessions found" : "No projects match your search"
                )
                Spacer()
            } else {
                List(selection: $selectedProject) {
                    ForEach(filteredProjects) { project in
                        ProjectSessionRow(
                            project: project,
                            byteFormatter: Self.byteFormatter,
                            dateFormatter: Self.relativeDateFormatter
                        )
                        .tag(project)
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            // Footer
            HStack {
                Text("\(filteredProjects.count) project\(filteredProjects.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .onChange(of: selectedProject) { _, newProject in
            selectedSession = nil
            messages = []
            metadata = nil
            if let project = newProject {
                let sorted = project.sessions.sorted { $0.lastModified > $1.lastModified }
                selectedSession = sorted.first
            }
        }
    }

    // MARK: - Column 2: Sessions

    @ViewBuilder
    private var sessionColumn: some View {
        VStack(spacing: 0) {
            if let project = selectedProject {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(project.sessions.count) session\(project.sessions.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        let projectDir = URL(fileURLWithPath: projectsBasePath)
                            .appendingPathComponent(project.id)
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: projectDir.path)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
                .padding(12)

                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search sessions...", text: $sessionSearchText)
                        .textFieldStyle(.plain)
                    if !sessionSearchText.isEmpty {
                        Button {
                            sessionSearchText = ""
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

                // Session list
                if sortedSessions.isEmpty {
                    Spacer()
                    EmptyContentPlaceholder(
                        icon: "doc.text",
                        title: "No Sessions",
                        subtitle: sessionSearchText.isEmpty ? "No sessions in this project" : "No sessions match your search"
                    )
                    Spacer()
                } else {
                    List(selection: $selectedSession) {
                        ForEach(sortedSessions) { session in
                            SessionItemRow(
                                session: session,
                                byteFormatter: Self.byteFormatter,
                                dateFormatter: Self.sessionDateFormatter,
                                timeFormatter: Self.shortTimeFormatter
                            )
                            .tag(session)
                        }
                    }
                    .listStyle(.sidebar)
                }
            } else {
                Spacer()
                EmptyContentPlaceholder(
                    icon: "folder",
                    title: "Select a Project",
                    subtitle: "Choose a project to view sessions"
                )
                Spacer()
            }
        }
        .onChange(of: selectedSession) { _, newSession in
            if let session = newSession, let project = selectedProject {
                loadSession(session, project: project)
            } else {
                messages = []
                metadata = nil
            }
        }
    }

    // MARK: - Column 3: Messages

    @ViewBuilder
    private var messageColumn: some View {
        if let session = selectedSession {
            VStack(spacing: 0) {
                // Toolbar with metadata
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundColor(.accentColor)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(Self.sessionDateFormatter.string(from: session.lastModified))
                            .font(.headline)
                            .lineLimit(1)
                        if let meta = metadata {
                            HStack(spacing: 4) {
                                if let first = meta.firstTimestamp, let last = meta.lastTimestamp {
                                    let duration = last.timeIntervalSince(first)
                                    Text(formatDuration(duration))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("·")
                                        .foregroundColor(.secondary)
                                }
                                Text(Self.byteFormatter.string(fromByteCount: session.size))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    if let meta = metadata {
                        HStack(spacing: 10) {
                            Label("\(meta.messageCount)", systemImage: "text.bubble")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !meta.modelsUsed.isEmpty {
                                Text(meta.modelsUsed.joined(separator: ", "))
                                    .font(.caption2.monospaced())
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            if !meta.toolsUsed.isEmpty {
                                Label("\(meta.toolsUsed.count) tools", systemImage: "hammer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassToolbar()

                // Message search
                SessionSearchView(searchText: $messageSearchText)
                    .padding(.top, 8)

                Divider()

                // Message thread
                if isLoadingMessages {
                    Spacer()
                    ProgressView("Parsing session...")
                        .font(.caption)
                    Spacer()
                } else if filteredMessages.isEmpty {
                    Spacer()
                    EmptyContentPlaceholder(
                        icon: "bubble.left.and.bubble.right",
                        title: messages.isEmpty ? "No Messages" : "No Results",
                        subtitle: messages.isEmpty ? "This session has no messages" : "No messages match your search"
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(filteredMessages.enumerated()), id: \.element.id) { index, message in
                                let prevRole = index > 0 ? filteredMessages[index - 1].role : nil
                                MessageBubbleView(message: message, previousRole: prevRole)
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .frame(minWidth: 400)
        } else {
            EmptyContentPlaceholder(
                icon: "bubble.left.and.bubble.right",
                title: "Select a Session",
                subtitle: "Choose a session to view the conversation"
            )
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let mins = Int(seconds / 60)
            return "\(mins)m"
        } else {
            let hours = Int(seconds / 3600)
            let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m"
        }
    }

    // MARK: - Data Loading

    private func loadProjects() {
        isLoadingProjects = true
        projects = configManager.loadProjects()
        isLoadingProjects = false

        if selectedProject == nil {
            let withSessions = projects.filter { !$0.sessions.isEmpty }
            selectedProject = withSessions.first
        }
    }

    private func loadSession(_ session: Session, project: Project) {
        isLoadingMessages = true
        messageSearchText = ""

        let projectDir = URL(fileURLWithPath: projectsBasePath)
            .appendingPathComponent(project.id)
        let sessionURL = projectDir.appendingPathComponent(session.filename)

        DispatchQueue.global(qos: .userInitiated).async {
            let parsed = SessionParser.parseSession(at: sessionURL)
            let meta = SessionParser.sessionMetadata(at: sessionURL)

            DispatchQueue.main.async {
                messages = parsed
                metadata = meta
                isLoadingMessages = false
            }
        }
    }
}

// MARK: - ProjectSessionRow

private struct ProjectSessionRow: View {
    let project: Project
    let byteFormatter: ByteCountFormatter
    let dateFormatter: RelativeDateTimeFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.displayName)
                .font(.body)
                .lineLimit(1)
            Text(project.originalPath)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text("\(project.sessions.count) session\(project.sessions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(byteFormatter.string(fromByteCount: project.totalSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let date = project.lastAccessed {
                    Text(dateFormatter.localizedString(for: date, relativeTo: Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - SessionItemRow

private struct SessionItemRow: View {
    let session: Session
    let byteFormatter: ByteCountFormatter
    let dateFormatter: DateFormatter
    let timeFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Date as primary label
            Text(dateFormatter.string(from: session.lastModified))
                .font(.body)
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(byteFormatter.string(fromByteCount: session.size))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(sessionShortId)
                    .font(.caption2.monospaced())
                    .foregroundColor(.secondary.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var sessionShortId: String {
        let name = session.filename
        if name.hasSuffix(".jsonl") {
            let id = String(name.dropLast(6))
            // Show just first 8 chars of UUID
            if id.count > 8 {
                return String(id.prefix(8)) + "..."
            }
            return id
        }
        return name
    }
}
