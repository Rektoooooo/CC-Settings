import SwiftUI

// MARK: - Data Models

private struct FileHistorySession: Identifiable, Hashable {
    let id: String
    var projectName: String
    var date: Date
    var fileCount: Int
    var fileGroups: [FileGroup]

    static func == (lhs: FileHistorySession, rhs: FileHistorySession) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct FileGroup: Identifiable, Hashable {
    let id: String
    var displayName: String
    var versions: [FileVersion]

    static func == (lhs: FileGroup, rhs: FileGroup) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct FileVersion: Identifiable, Hashable {
    let id: String
    let versionNumber: Int
    let url: URL
    let size: Int64
    let date: Date

    static func == (lhs: FileVersion, rhs: FileVersion) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - FileHistoryView

struct FileHistoryView: View {
    @EnvironmentObject var configManager: ConfigurationManager

    @State private var sessions: [FileHistorySession] = []
    @State private var selectedSessionId: String?
    @State private var selectedGroupId: String?
    @State private var selectedVersionId: String?
    @State private var sessionSearchText = ""
    @State private var fileSearchText = ""
    @State private var isLoadingSessions = false
    @State private var isLoadingFiles = false
    @State private var fileContent: String?
    @State private var diffContent: String?
    @State private var showingDiff = false
    @State private var filenameCache: [String: String] = [:]

    private static let fileHistoryPath: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/file-history").path
    }()

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useBytes, .useKB, .useMB]
        f.countStyle = .file
        return f
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

    private var selectedSession: FileHistorySession? {
        sessions.first { $0.id == selectedSessionId }
    }

    private var selectedGroup: FileGroup? {
        selectedSession?.fileGroups.first { $0.id == selectedGroupId }
    }

    private var filteredSessions: [FileHistorySession] {
        if sessionSearchText.isEmpty { return sessions }
        let query = sessionSearchText.lowercased()
        return sessions.filter {
            $0.projectName.lowercased().contains(query) ||
            $0.id.lowercased().contains(query)
        }
    }

    private var filteredFileGroups: [FileGroup] {
        guard let session = selectedSession else { return [] }
        if fileSearchText.isEmpty { return session.fileGroups }
        let query = fileSearchText.lowercased()
        return session.fileGroups.filter {
            $0.displayName.lowercased().contains(query) ||
            $0.id.lowercased().contains(query)
        }
    }

    var body: some View {
        HSplitView {
            sessionColumn
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)

            fileColumn
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 320)

            versionColumn
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
                    Image(systemName: "clock")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    Text("File History")
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
                Text("~/.claude/file-history")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
            .padding(12)

            searchField(text: $sessionSearchText, placeholder: "Search sessions...")
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Divider()

            if isLoadingSessions {
                Spacer()
                ProgressView("Loading sessions...")
                    .font(.caption)
                Spacer()
            } else if filteredSessions.isEmpty {
                Spacer()
                EmptyContentPlaceholder(
                    icon: "clock",
                    title: sessions.isEmpty ? "No File History" : "No Results",
                    subtitle: sessions.isEmpty ? "No file history sessions found" : "No sessions match your search"
                )
                Spacer()
            } else {
                List(filteredSessions, selection: $selectedSessionId) { session in
                    HistorySessionRow(
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
        .onChange(of: selectedSessionId) { _, newId in
            selectedGroupId = nil
            selectedVersionId = nil
            fileContent = nil
            diffContent = nil
            showingDiff = false
            if let id = newId {
                loadFileGroups(sessionId: id)
            }
        }
    }

    // MARK: - Column 2: Files

    @ViewBuilder
    private var fileColumn: some View {
        VStack(spacing: 0) {
            if let session = selectedSession {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.projectName)
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(session.fileGroups.count) file\(session.fileGroups.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        let dir = URL(fileURLWithPath: Self.fileHistoryPath)
                            .appendingPathComponent(session.id)
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
                .padding(12)

                searchField(text: $fileSearchText, placeholder: "Search files...")
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                Divider()

                if isLoadingFiles {
                    Spacer()
                    ProgressView("Loading files...")
                        .font(.caption)
                    Spacer()
                } else if filteredFileGroups.isEmpty {
                    Spacer()
                    EmptyContentPlaceholder(
                        icon: "doc",
                        title: "No Files",
                        subtitle: fileSearchText.isEmpty ? "No files in this session" : "No files match your search"
                    )
                    Spacer()
                } else {
                    List(filteredFileGroups, selection: $selectedGroupId) { group in
                        HistoryFileGroupRow(
                            group: group,
                            dateFormatter: Self.dateFormatter
                        )
                        .tag(group.id)
                    }
                    .listStyle(.sidebar)
                }
            } else {
                Spacer()
                EmptyContentPlaceholder(
                    icon: "clock",
                    title: "Select a Session",
                    subtitle: "Choose a session to view edited files"
                )
                Spacer()
            }
        }
        .onChange(of: selectedGroupId) { _, newId in
            selectedVersionId = nil
            fileContent = nil
            diffContent = nil
            showingDiff = false
            if let group = selectedSession?.fileGroups.first(where: { $0.id == newId }) {
                selectedVersionId = group.versions.last?.id
            }
        }
    }

    // MARK: - Column 3: Versions & Content

    @ViewBuilder
    private var versionColumn: some View {
        if let group = selectedGroup {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(group.versions.count) version\(group.versions.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Picker("Version", selection: $selectedVersionId) {
                        ForEach(group.versions) { version in
                            HStack {
                                Text("v\(version.versionNumber)")
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text(Self.byteFormatter.string(fromByteCount: version.size))
                                    .foregroundColor(.secondary)
                                Text("·")
                                    .foregroundColor(.secondary)
                                Text(Self.dateFormatter.string(from: version.date))
                                    .foregroundColor(.secondary)
                            }
                            .tag(Optional(version.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 350)

                    if group.versions.count >= 2 {
                        Button {
                            showingDiff.toggle()
                            if showingDiff {
                                computeDiff(for: group)
                            }
                        } label: {
                            Label(showingDiff ? "Content" : "Compare", systemImage: showingDiff ? "doc.text" : "arrow.left.arrow.right")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassToolbar()

                Divider()

                if showingDiff {
                    if let diff = diffContent {
                        DiffView(diff: diff, title: diffTitle(for: group))
                    } else {
                        Spacer()
                        ProgressView("Computing diff...")
                            .font(.caption)
                        Spacer()
                    }
                } else if let content = fileContent {
                    ScrollView([.horizontal, .vertical]) {
                        Text(content)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                } else {
                    Spacer()
                    ProgressView("Loading file...")
                        .font(.caption)
                    Spacer()
                }
            }
            .frame(minWidth: 400)
            .onChange(of: selectedVersionId) { _, newId in
                showingDiff = false
                diffContent = nil
                if let version = group.versions.first(where: { $0.id == newId }) {
                    loadFileContent(version.url)
                }
            }
        } else {
            EmptyContentPlaceholder(
                icon: "doc.text.magnifyingglass",
                title: "Select a File",
                subtitle: "Choose a file to view its version history"
            )
        }
    }

    // MARK: - Shared Components

    @ViewBuilder
    private func searchField(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Data Loading

    private func loadSessions() {
        isLoadingSessions = true
        let projects = configManager.loadProjects()

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let baseURL = URL(fileURLWithPath: Self.fileHistoryPath)

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
                    isLoadingSessions = false
                }
                return
            }

            var result: [FileHistorySession] = []
            for dir in dirs {
                guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                    continue
                }
                let sessionId = dir.lastPathComponent

                guard let files = try? fm.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ) else { continue }

                var hashes = Set<String>()
                var latestDate = Date.distantPast
                for file in files {
                    let name = file.lastPathComponent
                    if let atIndex = name.firstIndex(of: "@") {
                        hashes.insert(String(name[name.startIndex..<atIndex]))
                    }
                    if let modDate = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                       modDate > latestDate {
                        latestDate = modDate
                    }
                }

                let projectName = projectMap[sessionId] ?? "Unknown Project"
                result.append(FileHistorySession(
                    id: sessionId,
                    projectName: projectName,
                    date: latestDate,
                    fileCount: hashes.count,
                    fileGroups: []
                ))
            }

            result.sort { $0.date > $1.date }

            DispatchQueue.main.async {
                sessions = result
                isLoadingSessions = false
                if selectedSessionId == nil, let first = result.first {
                    selectedSessionId = first.id
                }
            }
        }
    }

    private func loadFileGroups(sessionId: String) {
        isLoadingFiles = true
        let cache = filenameCache

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let sessionDir = URL(fileURLWithPath: Self.fileHistoryPath)
                .appendingPathComponent(sessionId)

            guard let files = try? fm.contentsOfDirectory(
                at: sessionDir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                DispatchQueue.main.async {
                    isLoadingFiles = false
                }
                return
            }

            var groupMap: [String: [FileVersion]] = [:]
            for file in files {
                let name = file.lastPathComponent
                guard let atIndex = name.firstIndex(of: "@"),
                      name[name.index(after: atIndex)...].hasPrefix("v") else { continue }

                let hash = String(name[name.startIndex..<atIndex])
                let versionStr = String(name[name.index(atIndex, offsetBy: 2)...])
                guard let versionNum = Int(versionStr) else { continue }

                let attrs = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let version = FileVersion(
                    id: name,
                    versionNumber: versionNum,
                    url: file,
                    size: Int64(attrs?.fileSize ?? 0),
                    date: attrs?.contentModificationDate ?? Date.distantPast
                )
                groupMap[hash, default: []].append(version)
            }

            var groups: [FileGroup] = []
            var updatedCache = cache
            for (hash, versions) in groupMap {
                let sorted = versions.sorted { $0.versionNumber < $1.versionNumber }
                let displayName: String
                if let cached = updatedCache[hash] {
                    displayName = cached
                } else {
                    let extracted = Self.extractFilename(from: sorted.first?.url)
                    displayName = extracted ?? hash
                    updatedCache[hash] = displayName
                }
                groups.append(FileGroup(
                    id: hash,
                    displayName: displayName,
                    versions: sorted
                ))
            }

            groups.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            DispatchQueue.main.async {
                if let idx = sessions.firstIndex(where: { $0.id == sessionId }) {
                    sessions[idx].fileGroups = groups
                }
                filenameCache = updatedCache
                isLoadingFiles = false
            }
        }
    }

    private func loadFileContent(_ url: URL) {
        fileContent = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let content = try? String(contentsOf: url, encoding: .utf8)
            DispatchQueue.main.async {
                fileContent = content ?? "(Unable to read file)"
            }
        }
    }

    private func computeDiff(for group: FileGroup) {
        diffContent = nil
        guard group.versions.count >= 2 else { return }

        let v1URL = group.versions.first!.url
        let vLastURL = group.versions.last!.url

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/diff")
            process.arguments = ["-u", v1URL.path, vLastURL.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            try? process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                diffContent = output.isEmpty ? "No differences found." : output
            }
        }
    }

    private func diffTitle(for group: FileGroup) -> String {
        guard let first = group.versions.first, let last = group.versions.last else {
            return group.displayName
        }
        return "\(group.displayName) — v\(first.versionNumber) → v\(last.versionNumber)"
    }

    // MARK: - Filename Extraction

    private static func extractFilename(from url: URL?) -> String? {
        guard let url = url,
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }

        let preview = data.prefix(512)
        guard let text = String(data: preview, encoding: .utf8) else { return nil }

        let lines = text.components(separatedBy: .newlines)

        // Swift/ObjC/C: line 2 is typically "//  Filename.swift"
        if lines.count >= 2 {
            let line2 = lines[1].trimmingCharacters(in: .whitespaces)
            if line2.hasPrefix("//") {
                let name = line2.dropFirst(2).trimmingCharacters(in: .whitespaces)
                if name.contains(".") && !name.contains(" ") && name.count < 100 {
                    return name
                }
            }
        }

        // Markdown: line 1 is "# Title"
        if let first = lines.first?.trimmingCharacters(in: .whitespaces),
           first.hasPrefix("# ") {
            let title = String(first.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty && title.count < 100 {
                return title
            }
        }

        // JS/TS: check for "* Filename.ts" or similar in comment blocks
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("* ") || trimmed.hasPrefix("/** ") {
                let name = trimmed
                    .replacingOccurrences(of: "/** ", with: "")
                    .replacingOccurrences(of: "* ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if name.contains(".") && !name.contains(" ") && name.count < 100 {
                    return name
                }
            }
        }

        return nil
    }
}

// MARK: - Row Views

private struct HistorySessionRow: View {
    let session: FileHistorySession
    let dateFormatter: RelativeDateTimeFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.projectName)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text("\(session.fileCount) file\(session.fileCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

private struct HistoryFileGroupRow: View {
    let group: FileGroup
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: fileIcon)
                    .foregroundColor(.accentColor)
                    .frame(width: 16)
                Text(group.displayName)
                    .font(.body)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                Text("\(group.versions.count) version\(group.versions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let latest = group.versions.last {
                    Text(dateFormatter.string(from: latest.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var fileIcon: String {
        let name = group.displayName.lowercased()
        if name.hasSuffix(".swift") { return "swift" }
        if name.hasSuffix(".js") || name.hasSuffix(".ts") || name.hasSuffix(".tsx") || name.hasSuffix(".jsx") { return "chevron.left.forwardslash.chevron.right" }
        if name.hasSuffix(".py") { return "text.page" }
        if name.hasSuffix(".md") { return "doc.richtext" }
        if name.hasSuffix(".json") || name.hasSuffix(".yml") || name.hasSuffix(".yaml") { return "curlybraces" }
        if name.hasSuffix(".css") || name.hasSuffix(".scss") { return "paintbrush" }
        if name.hasSuffix(".html") { return "globe" }
        if name.contains(".") { return "doc.text" }
        return "doc"
    }
}
