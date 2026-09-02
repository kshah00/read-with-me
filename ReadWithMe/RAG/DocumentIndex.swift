import Foundation
import NaturalLanguage

/// A retrievable slice of the document, tagged with its page number.
struct DocChunk {
    let page: Int          // zero-based page index
    let text: String
    var vector: [Double]   // NLEmbedding sentence vector (may be empty if unavailable)
}

/// A lightweight, fully on-device retrieval index over a PDF's text.
///
/// Chunks are embedded with Apple's `NLEmbedding` (no network, no API cost) and
/// retrieved by cosine similarity. This gives the chatbot the *relevant* parts of
/// long documents that would never fit whole into a prompt, while the current page
/// is always injected separately by the caller so "what am I looking at" works.
actor DocumentIndex {
    private var chunks: [DocChunk] = []
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    var isEmpty: Bool { chunks.isEmpty }

    /// Builds the index from per-page plain text. Pages are split into overlapping
    /// word windows so a chunk keeps enough surrounding context to be meaningful.
    func build(pages: [String]) {
        var built: [DocChunk] = []
        for (pageIndex, pageText) in pages.enumerated() {
            let trimmed = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            for window in Self.windows(from: trimmed, size: 180, overlap: 40) {
                let vector = embedding?.vector(for: window.lowercased()) ?? []
                built.append(DocChunk(page: pageIndex, text: window, vector: vector))
            }
        }
        chunks = built
    }

    /// Returns the `k` chunks most relevant to `query`, best first.
    func topChunks(for query: String, k: Int = 5) -> [DocChunk] {
        guard !chunks.isEmpty else { return [] }
        guard let queryVec = embedding?.vector(for: query.lowercased()), !queryVec.isEmpty else {
            // No embedding model — fall back to naive keyword overlap.
            return keywordRanked(for: query, k: k)
        }
        let scored = chunks.compactMap { chunk -> (Double, DocChunk)? in
            guard !chunk.vector.isEmpty else { return nil }
            return (Self.cosine(queryVec, chunk.vector), chunk)
        }
        return scored.sorted { $0.0 > $1.0 }.prefix(k).map { $0.1 }
    }

    // MARK: - Helpers

    private func keywordRanked(for query: String, k: Int) -> [DocChunk] {
        let terms = Set(query.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
        let scored = chunks.map { chunk -> (Int, DocChunk) in
            let words = Set(chunk.text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            return (terms.intersection(words).count, chunk)
        }
        return scored.filter { $0.0 > 0 }.sorted { $0.0 > $1.0 }.prefix(k).map { $0.1 }
    }

    private static func windows(from text: String, size: Int, overlap: Int) -> [String] {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).map(String.init)
        guard words.count > size else { return [words.joined(separator: " ")] }
        var result: [String] = []
        var start = 0
        let step = max(1, size - overlap)
        while start < words.count {
            let end = min(start + size, words.count)
            result.append(words[start..<end].joined(separator: " "))
            if end == words.count { break }
            start += step
        }
        return result
    }

    private static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        guard na > 0, nb > 0 else { return 0 }
        return dot / (na.squareRoot() * nb.squareRoot())
    }
}
