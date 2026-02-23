import SwiftUI

@MainActor
struct FileViewerFactory {

    @ViewBuilder
    static func viewer(for file: ClaudeFile, readOnly: Bool) -> some View {
        switch file.type {
        case .markdown:
            MarkdownFileViewer(file: file, readOnly: readOnly)
        case .json:
            JSONFileViewer(file: file, readOnly: readOnly)
        case .pdf:
            PDFFileViewer(file: file)
        case .binary:
            BinaryFileInfoView(file: file)
        case .directory:
            DirectoryListingView(file: file)
        case .text, .unknown:
            TextFileViewer(file: file, readOnly: readOnly)
        }
    }
}
