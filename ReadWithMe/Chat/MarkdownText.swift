import SwiftUI

/// A lightweight Markdown renderer good enough for chat answers: headings,
/// bullet/numbered lists, fenced code blocks, and inline **bold** / *italic* /
/// `code` / links. Built on SwiftUI + AttributedString — no dependencies.
struct MarkdownText: View {
    let markdown: String
    var textColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block.view(textColor: textColor)
            }
        }
    }

    private var blocks: [Block] { Block.parse(markdown) }
}

private enum Block {
    case heading(level: Int, text: String)
    case bullet(text: String)
    case numbered(index: String, text: String)
    case code(String)
    case paragraph(String)

    @ViewBuilder
    func view(textColor: Color) -> some View {
        switch self {
        case .heading(let level, let text):
            inline(text)
                .font(.system(size: level <= 1 ? 17 : level == 2 ? 15 : 13.5, weight: .bold))
                .foregroundStyle(textColor)
                .padding(.top, 2)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•").font(.system(size: 13)).foregroundStyle(textColor.opacity(0.7))
                inline(text).foregroundStyle(textColor)
            }
        case .numbered(let index, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(index).").font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(textColor.opacity(0.7))
                inline(text).foregroundStyle(textColor)
            }
        case .code(let code):
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(textColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        case .paragraph(let text):
            inline(text).foregroundStyle(textColor)
        }
    }

    private func inline(_ raw: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: raw, options: options) {
            return Text(attributed).font(.system(size: 13))
        }
        return Text(raw).font(.system(size: 13))
    }

    // MARK: - Parsing

    static func parse(_ markdown: String) -> [Block] {
        var blocks: [Block] = []
        var inCode = false
        var codeBuffer: [String] = []

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine

            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCode {
                    blocks.append(.code(codeBuffer.joined(separator: "\n")))
                    codeBuffer.removeAll()
                }
                inCode.toggle()
                continue
            }
            if inCode { codeBuffer.append(line); continue }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if let hMatch = headingLevel(trimmed) {
                blocks.append(.heading(level: hMatch.0, text: hMatch.1))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                blocks.append(.bullet(text: String(trimmed.dropFirst(2))))
            } else if let num = numberedItem(trimmed) {
                blocks.append(.numbered(index: num.0, text: num.1))
            } else {
                blocks.append(.paragraph(trimmed))
            }
        }
        if inCode, !codeBuffer.isEmpty {
            blocks.append(.code(codeBuffer.joined(separator: "\n")))
        }
        return blocks
    }

    private static func headingLevel(_ line: String) -> (Int, String)? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        var idx = line.startIndex
        while idx < line.endIndex, line[idx] == "#", level < 6 {
            level += 1; idx = line.index(after: idx)
        }
        guard idx < line.endIndex, line[idx] == " " else { return nil }
        return (level, String(line[line.index(after: idx)...]))
    }

    private static func numberedItem(_ line: String) -> (String, String)? {
        let parts = line.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let first = parts.first,
              !first.isEmpty, first.allSatisfy(\.isNumber),
              parts[1].hasPrefix(" ") else { return nil }
        return (String(first), String(parts[1].dropFirst()))
    }
}
