import Foundation

/// A single message in an Azure OpenAI chat request.
struct ChatWireMessage {
    let role: String   // "system" | "user" | "assistant"
    let content: String
}

enum ChatError: LocalizedError {
    case notConfigured
    case badResponse(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Add your Azure OpenAI key to Config/Secrets.plist."
        case .badResponse(let status, let body):
            return "The model request failed (\(status)). \(body)"
        }
    }
}

/// Streaming client for Azure OpenAI chat completions.
enum ChatClient {
    /// Streams the assistant's reply token-by-token. Each partial delta is
    /// delivered through `onDelta` on the main actor; the full text is returned.
    @discardableResult
    static func stream(
        messages: [ChatWireMessage],
        config: AzureConfig,
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        guard let endpoint = config.chatCompletionsURL else { throw ChatError.notConfigured }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let payload: [String: Any] = [
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            // Drain the body for a useful error message.
            var body = ""
            for try await line in bytes.lines { body += line }
            throw ChatError.badResponse(status: status, body: body)
        }

        var full = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payloadText = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payloadText == "[DONE]" { break }
            guard let data = payloadText.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = obj["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let piece = delta["content"] as? String, !piece.isEmpty
            else { continue }
            full += piece
            let snapshot = piece
            await MainActor.run { onDelta(snapshot) }
        }
        return full
    }
}
