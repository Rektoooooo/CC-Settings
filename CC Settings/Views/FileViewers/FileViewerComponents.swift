import SwiftUI

// MARK: - FileViewerToolbar

struct FileViewerToolbar<TrailingContent: View>: View {
    let file: ClaudeFile
    let readOnly: Bool
    let hasChanges: Bool
    var onSave: (() -> Void)? = nil
    var onRevert: (() -> Void)? = nil
    @ViewBuilder let trailingContent: () -> TrailingContent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.type.icon)
                .foregroundColor(file.type.color)
                .font(.title3)

            Text(file.name)
                .font(.headline)
                .lineLimit(1)

            trailingContent()

            Spacer()

            if hasChanges && !readOnly {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)
                    .help("Unsaved changes")
            }

            if !readOnly {
                if hasChanges {
                    Button {
                        onRevert?()
                    } label: {
                        Text("Revert")
                    }
                }

                Button {
                    onSave?()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!hasChanges)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassToolbar()
    }
}

extension FileViewerToolbar where TrailingContent == EmptyView {
    init(
        file: ClaudeFile,
        readOnly: Bool,
        hasChanges: Bool,
        onSave: (() -> Void)? = nil,
        onRevert: (() -> Void)? = nil
    ) {
        self.file = file
        self.readOnly = readOnly
        self.hasChanges = hasChanges
        self.onSave = onSave
        self.onRevert = onRevert
        self.trailingContent = { EmptyView() }
    }
}

// MARK: - ViewModePicker

enum ViewMode: String, CaseIterable {
    case source = "Source"
    case preview = "Preview"
    case split = "Split"

    var icon: String {
        switch self {
        case .source: return "doc.text"
        case .preview: return "eye"
        case .split: return "square.split.2x1"
        }
    }
}

struct ViewModePicker: View {
    @Binding var mode: ViewMode

    var body: some View {
        Picker("", selection: $mode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Label(mode.rawValue, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }
}

// MARK: - PaneHeader

struct PaneHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption)
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: Rectangle())
    }
}

// MARK: - ReadOnlyBanner

/// Tracks the on-disk modification date a raw editor loaded, so a save can detect
/// that something else (typically the Claude Code CLI) wrote the file meanwhile.
struct FileEditGuard {
    private(set) var loadedModDate: Date?
    private(set) var conflict = false
    private(set) var errorMessage: String?

    static func modDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.resolvingWriteTarget().path))?[.modificationDate] as? Date
    }

    mutating func markLoaded(_ url: URL) {
        loadedModDate = Self.modDate(of: url)
        conflict = false
        errorMessage = nil
    }

    /// Writes `content` unless the file changed since load (then flags a conflict
    /// and writes nothing). `force` is the user's explicit "Overwrite". Returns true on success.
    mutating func save(_ content: String, to url: URL, force: Bool = false) -> Bool {
        if !force, Self.modDate(of: url) != loadedModDate {
            conflict = true
            return false
        }
        do {
            try content.writeAtomicallyFollowingSymlinks(to: url)
            markLoaded(url)
            return true
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
            return false
        }
    }
}

struct FileConflictBanner: View {
    let state: FileEditGuard
    var onReload: () -> Void
    var onOverwrite: () -> Void

    var body: some View {
        if state.conflict {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text("This file changed on disk since you opened it. Saving now would discard those changes.")
                    .font(.caption)
                Spacer()
                Button("Reload", action: onReload).controlSize(.small)
                Button("Overwrite", role: .destructive, action: onOverwrite).controlSize(.small)
            }
            .padding(8)
            .glassBanner(tint: .orange)
            .padding(.horizontal, 12)
        } else if let message = state.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                Text(message).font(.caption)
                Spacer()
            }
            .padding(8)
            .glassBanner(tint: .red)
            .padding(.horizontal, 12)
        }
    }
}

struct ReadOnlyBanner: View {
    var message: String = "This file is read-only."

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.themeAccent)
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBanner(tint: .themeAccent)
        .padding(.horizontal, 12)
    }
}

// MARK: - EmptyContentPlaceholder

struct EmptyContentPlaceholder: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
