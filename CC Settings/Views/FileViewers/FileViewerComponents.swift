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

struct ReadOnlyBanner: View {
    var message: String = "This file is read-only."

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBanner(tint: .blue)
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
