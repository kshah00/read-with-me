import SwiftUI
import PDFKit

/// SwiftUI wrapper around PDFKit's PDFView. Reports page changes and selection
/// back into the shared document model so the chatbot always knows the context.
struct PDFViewerView: NSViewRepresentable {
    @ObservedObject var model: PDFDocumentModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor.clear
        view.pageShadowsEnabled = true
        model.pdfView = view

        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged, object: view)
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged, object: view)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== model.document {
            view.document = model.document
            model.pdfView = view
        }
    }

    final class Coordinator: NSObject {
        let model: PDFDocumentModel
        init(model: PDFDocumentModel) { self.model = model }

        @objc func pageChanged(_ note: Notification) {
            guard let view = note.object as? PDFView,
                  let page = view.currentPage,
                  let doc = view.document else { return }
            let idx = doc.index(for: page)
            Task { @MainActor in self.model.currentPageIndex = idx }
        }

        @objc func selectionChanged(_ note: Notification) {
            guard let view = note.object as? PDFView else { return }
            let text = view.currentSelection?.string ?? ""
            Task { @MainActor in self.model.currentSelection = text }
        }
    }
}
