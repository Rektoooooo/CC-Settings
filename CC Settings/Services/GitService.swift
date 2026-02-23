import Foundation
import SwiftUI

@MainActor
class GitService: ObservableObject {
    static let shared = GitService()

    @Published var isGitRepo: Bool = false
    @Published var isGitInstalled: Bool = true
    @Published var isDirty: Bool = false
    @Published var currentBranch: String = "main"
    @Published var lastCommitDate: Date?
    @Published var lastCommitMessage: String = ""
    @Published var remoteURL: String?
    @Published var changedFiles: [GitFileChange] = []
    @Published var commitLog: [GitCommit] = []
    @Published var isLoading: Bool = false

    @Published var repoPath: URL {
        didSet {
            if repoPath != oldValue {
                resetState()
                refreshStatus()
            }
        }
    }

    private let gitPath = "/usr/bin/git"

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        repoPath = home.appendingPathComponent(".claude")
    }

    // MARK: - State Management

    func resetState() {
        isGitRepo = false
        isDirty = false
        currentBranch = "main"
        lastCommitDate = nil
        lastCommitMessage = ""
        remoteURL = nil
        changedFiles = []
        commitLog = []
    }

    // MARK: - Result type for cross-isolation transfer

    private struct RefreshResult: Sendable {
        let isInstalled: Bool
        let isRepo: Bool
        let branch: String
        let isDirty: Bool
        let lastMessage: String
        let lastDate: Date?
        let remote: String?
        let files: [GitFileChange]
        let log: [GitCommit]
    }

    // MARK: - Repo Detection

    nonisolated static func isGitRepository(at url: URL) -> Bool {
        let gitPath = "/usr/bin/git"
        guard FileManager.default.isExecutableFile(atPath: gitPath) else { return false }
        let result = git(gitPath, url, ["rev-parse", "--is-inside-work-tree"])
        return result.exit == 0
    }

    // MARK: - Refresh (non-blocking)

    func refreshStatus() {
        isLoading = true
        let path = gitPath
        let dir = repoPath
        Task {
            let result = await Self.doRefresh(path: path, dir: dir)
            isGitInstalled = result.isInstalled
            isGitRepo = result.isRepo
            currentBranch = result.branch
            isDirty = result.isDirty
            lastCommitMessage = result.lastMessage
            lastCommitDate = result.lastDate
            remoteURL = result.remote
            changedFiles = result.files
            commitLog = result.log
            isLoading = false
        }
    }

    // Runs off @MainActor since it's nonisolated + async
    nonisolated private static func doRefresh(path: String, dir: URL) async -> RefreshResult {
        let installed = FileManager.default.isExecutableFile(atPath: path)
        guard installed else {
            return RefreshResult(isInstalled: false, isRepo: false, branch: "main",
                                isDirty: false, lastMessage: "", lastDate: nil,
                                remote: nil, files: [], log: [])
        }

        let isRepo = git(path, dir, ["rev-parse", "--is-inside-work-tree"]).exit == 0
        guard isRepo else {
            return RefreshResult(isInstalled: true, isRepo: false, branch: "main",
                                isDirty: false, lastMessage: "", lastDate: nil,
                                remote: nil, files: [], log: [])
        }

        let branchResult = git(path, dir, ["branch", "--show-current"])
        let branch = (branchResult.exit == 0 && !branchResult.output.isEmpty) ? branchResult.output : "main"

        let files = fetchChangedFiles(path, dir)
        let (lastMsg, lastDate) = fetchLastCommit(path, dir)

        let remoteResult = git(path, dir, ["remote", "get-url", "origin"])
        let remote = (remoteResult.exit == 0 && !remoteResult.output.isEmpty) ? remoteResult.output : nil

        let log = fetchLog(path, dir, limit: 20)

        return RefreshResult(isInstalled: true, isRepo: true, branch: branch,
                             isDirty: !files.isEmpty, lastMessage: lastMsg,
                             lastDate: lastDate, remote: remote, files: files, log: log)
    }

    // MARK: - Init Repo

    func initRepo() async -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(at: repoPath, withIntermediateDirectories: true)

        let (_, initExit) = await runGit(["init"])
        guard initExit == 0 else { return false }

        let gitignoreURL = repoPath.appendingPathComponent(".gitignore")
        do {
            try Self.defaultGitignoreContent.write(to: gitignoreURL, atomically: true, encoding: .utf8)
        } catch {
            return false
        }

        let (_, addExit) = await runGit(["add", "."])
        guard addExit == 0 else { return false }

        let (_, commitExit) = await runGit(["commit", "-m", "Initial commit - track Claude Code settings"])
        guard commitExit == 0 else { return false }

        refreshStatus()
        return true
    }

    // MARK: - Commit (non-blocking)

    func commit(message: String, files: [String]) {
        guard !message.isEmpty, !files.isEmpty else { return }
        isLoading = true
        let path = gitPath
        let dir = repoPath

        Task {
            await Self.doCommit(path: path, dir: dir, message: message, files: files)
            refreshStatus()
        }
    }

    /// Legacy convenience: commits all changed files
    func saveSnapshot(message: String) {
        let filePaths = changedFiles.map(\.path)
        commit(message: message, files: filePaths)
    }

    nonisolated private static func doCommit(path: String, dir: URL, message: String, files: [String]) async {
        for file in files {
            _ = git(path, dir, ["add", "--", file])
        }
        _ = git(path, dir, ["commit", "-m", message])
    }

    // MARK: - Remote

    func addRemote(url: String) async -> Bool {
        let (_, checkExit) = await runGit(["remote", "get-url", "origin"])
        if checkExit == 0 {
            await runGit(["remote", "set-url", "origin", url])
        } else {
            let (_, addExit) = await runGit(["remote", "add", "origin", url])
            if addExit != 0 { return false }
        }
        refreshStatus()
        return true
    }

    func removeRemote() async -> Bool {
        let (_, exitCode) = await runGit(["remote", "remove", "origin"])
        if exitCode == 0 {
            refreshStatus()
            return true
        }
        return false
    }

    func push(completion: @escaping @MainActor @Sendable (Bool, String) -> Void) {
        let path = gitPath
        let dir = repoPath
        let branch = currentBranch

        Task {
            let result = await Self.doPush(path: path, dir: dir, branch: branch)
            completion(result.0, result.1)
        }
    }

    nonisolated private static func doPush(path: String, dir: URL, branch: String) async -> (Bool, String) {
        let result = git(path, dir, ["push", "-u", "origin", branch])
        return (result.exit == 0, result.output)
    }

    func pull(completion: @escaping @MainActor @Sendable (Bool, String) -> Void) {
        let path = gitPath
        let dir = repoPath

        Task {
            let result = await Self.doPull(path: path, dir: dir)
            completion(result.0, result.1)
        }
    }

    nonisolated private static func doPull(path: String, dir: URL) async -> (Bool, String) {
        let result = git(path, dir, ["pull"])
        return (result.exit == 0, result.output)
    }

    // MARK: - Diff

    /// Async diff — captures repoPath on main actor, runs git off-thread
    func getDiffAsync(for file: String) async -> String {
        let path = gitPath
        let dir = repoPath
        return await Self.fetchDiff(path: path, dir: dir, file: file)
    }

    nonisolated private static func fetchDiff(path: String, dir: URL, file: String) async -> String {
        let staged = git(path, dir, ["diff", "--cached", "--", file])
        let unstaged = git(path, dir, ["diff", "--", file])
        let combined = [staged.output, unstaged.output].filter { !$0.isEmpty }.joined(separator: "\n")
        if combined.isEmpty {
            let fileURL = dir.appendingPathComponent(file)
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                let lines = content.components(separatedBy: "\n")
                var diff = "--- /dev/null\n+++ b/\(file)\n@@ -0,0 +1,\(lines.count) @@\n"
                for line in lines {
                    diff += "+\(line)\n"
                }
                return diff
            }
        }
        return combined
    }

    /// Async commit diff — captures repoPath on main actor, runs git off-thread
    func getCommitDiffAsync(hash: String) async -> String {
        let path = gitPath
        let dir = repoPath
        return await Self.fetchCommitDiff(path: path, dir: dir, hash: hash)
    }

    nonisolated private static func fetchCommitDiff(path: String, dir: URL, hash: String) async -> String {
        let result = git(path, dir, ["show", "--format=", hash])
        return result.output
    }

    // MARK: - Helpers

    static let defaultGitignoreContent = """
    # Session files (large, machine-specific)
    projects/*/sessions/*.jsonl
    projects/*/*.jsonl

    # Log files
    *.log

    # OS files
    .DS_Store

    # Credentials and tokens
    credentials.json
    *.token

    # Backup files
    *.bak
    """

    func defaultGitignore() -> String {
        Self.defaultGitignoreContent
    }

    // Async git — captures repoPath on main actor, runs Process off-thread
    @discardableResult
    private func runGit(_ args: [String]) async -> (output: String, exitCode: Int32) {
        let path = gitPath
        let dir = repoPath
        let result = await Self.runGitOffMain(path: path, dir: dir, args: args)
        return (result.output, result.exit)
    }

    nonisolated private static func runGitOffMain(path: String, dir: URL, args: [String]) async -> (output: String, exit: Int32) {
        git(path, dir, args)
    }

    // Static git execution (safe to call from any thread)
    nonisolated private static func git(_ gitPath: String, _ dir: URL, _ args: [String]) -> (output: String, exit: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        process.arguments = args
        process.currentDirectoryURL = dir

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return ("", 1)
        }

        // Read pipe data BEFORE waitUntilExit to avoid deadlock when
        // git output exceeds the 64KB pipe buffer.
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: outData, encoding: .utf8) ?? ""
        let errOutput = String(data: errData, encoding: .utf8) ?? ""

        let combined = output.isEmpty ? errOutput : output
        return (combined.trimmingCharacters(in: .whitespacesAndNewlines), process.terminationStatus)
    }

    // MARK: - Static Fetch Helpers

    nonisolated private static func fetchChangedFiles(_ gitPath: String, _ dir: URL) -> [GitFileChange] {
        var files: [GitFileChange] = []

        let staged = git(gitPath, dir, ["diff", "--cached", "--name-status"])
        if staged.exit == 0 {
            for line in staged.output.components(separatedBy: "\n") where !line.isEmpty {
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count >= 2 else { continue }
                let status = GitFileStatus(rawValue: String(parts[0].prefix(1))) ?? .modified
                files.append(GitFileChange(path: String(parts[1]), status: status, staged: true))
            }
        }

        let unstaged = git(gitPath, dir, ["diff", "--name-status"])
        if unstaged.exit == 0 {
            for line in unstaged.output.components(separatedBy: "\n") where !line.isEmpty {
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count >= 2 else { continue }
                let path = String(parts[1])
                if !files.contains(where: { $0.path == path }) {
                    let status = GitFileStatus(rawValue: String(parts[0].prefix(1))) ?? .modified
                    files.append(GitFileChange(path: path, status: status, staged: false))
                }
            }
        }

        let untracked = git(gitPath, dir, ["ls-files", "--others", "--exclude-standard"])
        if untracked.exit == 0 {
            for line in untracked.output.components(separatedBy: "\n") where !line.isEmpty {
                if !files.contains(where: { $0.path == line }) {
                    files.append(GitFileChange(path: line, status: .untracked, staged: false))
                }
            }
        }

        return files.sorted { $0.path < $1.path }
    }

    nonisolated private static func fetchLastCommit(_ gitPath: String, _ dir: URL) -> (String, Date?) {
        let format = "%H%n%h%n%s%n%an%n%aI"
        let result = git(gitPath, dir, ["log", "-1", "--format=\(format)"])
        guard result.exit == 0, !result.output.isEmpty else {
            return ("", nil)
        }
        let lines = result.output.components(separatedBy: "\n")
        guard lines.count >= 5 else { return ("", nil) }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return (lines[2], formatter.date(from: lines[4]))
    }

    nonisolated private static func fetchLog(_ gitPath: String, _ dir: URL, limit: Int = 50) -> [GitCommit] {
        let recordSep = "---GIT_RECORD---"
        let fieldSep = "---GIT_FIELD---"
        // Each record: <recordSep>\n<H>\n<h>\n<s>\n<an>\n<aI>
        let format = "\(recordSep)%n%H\(fieldSep)%h\(fieldSep)%s\(fieldSep)%an\(fieldSep)%aI"
        let result = git(gitPath, dir, ["log", "--format=\(format)", "-n", "\(limit)"])
        guard result.exit == 0, !result.output.isEmpty else { return [] }

        var commits: [GitCommit] = []
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let records = result.output.components(separatedBy: recordSep)
        for record in records {
            let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let fields = trimmed.components(separatedBy: fieldSep)
            guard fields.count >= 5 else { continue }

            commits.append(GitCommit(
                id: fields[0],
                shortHash: fields[1],
                message: fields[2],
                author: fields[3],
                date: formatter.date(from: fields[4]) ?? Date(),
                filesChanged: 0
            ))
        }

        return commits
    }
}
