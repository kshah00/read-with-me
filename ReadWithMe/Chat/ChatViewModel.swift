import Foundation
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published var isResponding = false
    @Published var errorText: String?

    private let doc: PDFDocumentModel
    private let settings: SettingsStore

    init(doc: PDFDocumentModel, settings: SettingsStore) {
        self.doc = doc
        self.settings = settings
    }

    var isConfigured: Bool { settings.azureConfig?.chatCompletionsURL != nil }

    private let systemPrompt = """
    You are ReadWithMe, a sharp and friendly reading companion embedded in a PDF \
    viewer. The user is reading a document and asks you questions, doubts, and \
    queries about it. You are given the text of the page they are currently looking \
    at, anything they have highlighted, and the most relevant passages retrieved \
    from elsewhere in the document. Ground your answers in that provided context and \
    cite page numbers when you use them (e.g. "on page 4…"). If the answer is not in \
    the provided context, say so briefly and answer from general knowledge, making \
    clear you are doing so. Be concise and conversational.
    """

    func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isResponding else { return }
        guard let config = settings.azureConfig else {
            errorText = "Add your Azure OpenAI credentials in Settings (⌘,)."
            return
        }
        input = ""
        errorText = nil
        messages.append(ChatMessage(role: .user, text: question))

        var assistant = ChatMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(assistant)
        let assistantID = assistant.id
        isResponding = true

        Task {
            let context = await doc.contextBlock(for: question)
            var wire: [ChatWireMessage] = [.init(role: "system", content: systemPrompt)]
            if !context.isEmpty {
                wire.append(.init(role: "system", content: "Document context for this question:\n\n\(context)"))
            }
            // Include a short window of prior turns for continuity.
            for m in messages.dropLast() where !m.text.isEmpty {
                wire.append(.init(role: m.role == .user ? "user" : "assistant", content: m.text))
            }

            do {
                try await ChatClient.stream(messages: wire, config: config) { [weak self] delta in
                    guard let self else { return }
                    if let i = self.messages.firstIndex(where: { $0.id == assistantID }) {
                        self.messages[i].text += delta
                    }
                }
            } catch {
                if let i = self.messages.firstIndex(where: { $0.id == assistantID }) {
                    self.messages[i].text = "⚠️ \(error.localizedDescription)"
                }
            }
            if let i = self.messages.firstIndex(where: { $0.id == assistantID }) {
                self.messages[i].isStreaming = false
            }
            assistant.isStreaming = false
            isResponding = false
        }
    }

    func clear() {
        messages.removeAll()
        errorText = nil
    }
}
