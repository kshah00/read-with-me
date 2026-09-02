import Foundation
import PDFKit
import Combine

/// Holds the open document, tracks what the reader is currently looking at, and
/// owns the on-device retrieval index that gives the chatbot document context.
@MainActor
final class PDFDocumentModel: ObservableObject {
    @Published var document: PDFDocument?
    @Published var documentTitle: String = "No document"
    @Published var currentPageIndex: Int = 0
    @Published var pageCount: Int = 0
    @Published var isIndexing = false
    @Published var currentSelection: String = ""

    /// The live PDFView, held so the chat/toolbar can drive highlighting and
    /// navigation. Set by the viewer when it is created.
    weak var pdfView: PDFView?

    let index = DocumentIndex()
    private var pageTexts: [String] = []

    // MARK: - Loading

    func open(url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let doc = PDFDocument(url: url) else { return }
        document = doc
        documentTitle = url.deletingPathExtension().lastPathComponent
        pageCount = doc.pageCount
        currentPageIndex = 0

        // Extract per-page text, then build the retrieval index off the main thread.
        var texts: [String] = []
        for i in 0..<doc.pageCount {
            texts.append(doc.page(at: i)?.string ?? "")
        }
        pageTexts = texts

        isIndexing = true
        Task {
            await index.build(pages: texts)
            await MainActor.run { self.isIndexing = false }
        }
    }

    // MARK: - Context for the model

    /// Text of the page (and its immediate neighbours) the reader is looking at.
    var currentPageText: String {
        guard !pageTexts.isEmpty else { return "" }
        let lo = max(0, currentPageIndex - 1)
        let hi = min(pageTexts.count - 1, currentPageIndex + 1)
        return (lo...hi).map { "[Page \($0 + 1)]\n\(pageTexts[$0])" }
            .joined(separator: "\n\n")
    }

    /// Assembles the document context block for a given question: the current
    /// view plus the most relevant retrieved passages from anywhere in the PDF.
    func contextBlock(for question: String) async -> String {
        var parts: [String] = []

        let onScreen = currentPageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !onScreen.isEmpty {
            parts.append("=== What the reader is currently looking at (page \(currentPageIndex + 1) of \(pageCount)) ===\n\(clip(onScreen, 6000))")
        }
        if !currentSelection.isEmpty {
            parts.append("=== Text the reader has highlighted/selected ===\n\(clip(currentSelection, 2000))")
        }
        let retrieved = await index.topChunks(for: question, k: 5)
        if !retrieved.isEmpty {
            let passages = retrieved.enumerated().map { i, c in
                "[Passage \(i + 1) — from page \(c.page + 1)]\n\(c.text)"
            }.joined(separator: "\n\n")
            parts.append("=== Relevant passages retrieved from elsewhere in the document ===\n\(passages)")
        }
        return parts.joined(separator: "\n\n")
    }

    private func clip(_ s: String, _ max: Int) -> String {
        s.count <= max ? s : String(s.prefix(max)) + "…"
    }

    // MARK: - Navigation & annotation (driven from SwiftUI)

    func goToPage(_ i: Int) {
        guard let doc = document, let page = doc.page(at: i) else { return }
        pdfView?.go(to: page)
    }

    /// Highlights the reader's current text selection with a yellow annotation.
    func highlightSelection() {
        guard let pdfView, let selection = pdfView.currentSelection else { return }
        for line in selection.selectionsByLine() {
            guard let page = line.pages.first else { continue }
            let bounds = line.bounds(for: page)
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = NSColor.systemYellow.withAlphaComponent(0.45)
            page.addAnnotation(annotation)
        }
        pdfView.clearSelection()
    }
}
