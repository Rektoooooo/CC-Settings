import SwiftUI

struct TextFileViewer: View {
    let file: ClaudeFile
    let readOnly: Bool

    @State private var content: String = ""
    @State private var originalContent: String = ""

    private var hasChanges: Bool {
        content != originalContent
    }

    private var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }

    private var wordCount: Int {
        let words = content.split { $0.isWhitespace || $0.isNewline }
        return words.count
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
                Text("\(lineCount) lines, \(wordCount) words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            if readOnly {
                ReadOnlyBanner()
            }

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
        .id(file.id)
        .onAppear(perform: loadContent)
        .onChange(of: file.id) {
            loadContent()
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
