import SwiftUI

struct MarkdownFileViewer: View {
    let file: ClaudeFile
    let readOnly: Bool

    @State private var content: String = ""
    @State private var originalContent: String = ""
    @State private var viewMode: ViewMode = .preview

    private var hasChanges: Bool {
        content != originalContent
    }

    var body: some View {
        VStack(spacing: 0) {
            FileViewerToolbar(
                file: file,
                readOnly: readOnly,
                hasChanges: hasChanges,
                onSave: save,
                onRevert: revert
            ) {
                ViewModePicker(mode: $viewMode)
            }

            Divider()

            if readOnly && viewMode != .preview {
                ReadOnlyBanner()
            }

            switch viewMode {
            case .source:
                sourceView
            case .preview:
                previewView
            case .split:
                splitView
            }
        }
        .id(file.id)
        .onAppear(perform: loadContent)
        .onChange(of: file.id) {
            loadContent()
        }
    }

    @ViewBuilder
    private var sourceView: some View {
        if readOnly {
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
        } else {
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(4)
        }
    }

    private var previewView: some View {
        ScrollView {
            MarkdownPreview(markdown: content)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var splitView: some View {
        HSplitView {
            VStack(spacing: 0) {
                PaneHeader(icon: "doc.text", title: "Source")
                Divider()
                sourceView
            }
            .frame(minWidth: 200)

            VStack(spacing: 0) {
                PaneHeader(icon: "eye", title: "Preview")
                Divider()
                previewView
            }
            .frame(minWidth: 200)
        }
    }

    private func loadContent() {
        if let text = try? String(contentsOf: file.path, encoding: .utf8) {
            content = text
            originalContent = text
        } else {
            content = ""
            originalContent = ""
        }
    }

    private func save() {
        do {
            try content.write(to: file.path, atomically: true, encoding: .utf8)
            originalContent = content
        } catch {
            print("Failed to save file: \(error)")
        }
    }

    private func revert() {
        content = originalContent
    }
}
