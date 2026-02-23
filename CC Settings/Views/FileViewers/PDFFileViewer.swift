import SwiftUI
import PDFKit

struct PDFFileViewer: View {
    let file: ClaudeFile

    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 1
    @State private var zoomLevel: CGFloat = 1.0
    @State private var pdfDocument: PDFDocument?

    private let minZoom: CGFloat = 0.25
    private let maxZoom: CGFloat = 4.0
    private let zoomStep: CGFloat = 1.25

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Image(systemName: file.type.icon)
                    .foregroundColor(file.type.color)
                    .font(.title3)

                Text(file.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                // Page navigation
                HStack(spacing: 4) {
                    Button {
                        if currentPage > 1 {
                            currentPage -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentPage <= 1)

                    Text("Page \(currentPage) of \(totalPages)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 80)

                    Button {
                        if currentPage < totalPages {
                            currentPage += 1
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentPage >= totalPages)
                }

                Divider()
                    .frame(height: 16)

                // Zoom controls
                HStack(spacing: 4) {
                    Button {
                        zoomOut()
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .disabled(zoomLevel <= minZoom)

                    Text("\(Int(zoomLevel * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40)

                    Button {
                        zoomIn()
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .disabled(zoomLevel >= maxZoom)

                    Button {
                        zoomLevel = 1.0
                    } label: {
                        Image(systemName: "1.magnifyingglass")
                    }
                    .help("Reset zoom")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassToolbar()

            Divider()

            // PDF content
            if let document = pdfDocument {
                PDFKitView(
                    document: document,
                    currentPage: $currentPage,
                    zoomLevel: $zoomLevel
                )
            } else {
                EmptyContentPlaceholder(
                    icon: "doc.text.fill",
                    title: "Unable to load PDF",
                    subtitle: "The file could not be opened as a PDF document."
                )
            }
        }
        .id(file.id)
        .onAppear(perform: loadPDF)
        .onChange(of: file.id) {
            loadPDF()
        }
    }

    private func loadPDF() {
        if let document = PDFDocument(url: file.path) {
            pdfDocument = document
            totalPages = document.pageCount
            currentPage = 1
            zoomLevel = 1.0
        } else {
            pdfDocument = nil
            totalPages = 1
            currentPage = 1
        }
    }

    private func zoomIn() {
        let newZoom = zoomLevel * zoomStep
        zoomLevel = min(newZoom, maxZoom)
    }

    private func zoomOut() {
        let newZoom = zoomLevel / zoomStep
        zoomLevel = max(newZoom, minZoom)
    }
}

// MARK: - PDFKitView (NSViewRepresentable)

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    @Binding var zoomLevel: CGFloat

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.scaleFactor = zoomLevel

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }

        // Update zoom
        if abs(pdfView.scaleFactor - zoomLevel) > 0.01 {
            pdfView.scaleFactor = zoomLevel
        }

        // Navigate to page
        let pageIndex = currentPage - 1
        if pageIndex >= 0, pageIndex < document.pageCount,
           let page = document.page(at: pageIndex),
           pdfView.currentPage !== page {
            pdfView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject {
        var parent: PDFKitView

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        @objc nonisolated func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            MainActor.assumeIsolated {
                guard let page = pdfView.currentPage,
                      let doc = pdfView.document else {
                    return
                }
                let pageIndex = doc.index(for: page)
                self.parent.currentPage = pageIndex + 1
            }
        }
    }
}
