import Foundation

enum TranscriberError: LocalizedError {
    case notConfigured
    case badResponse(status: Int, body: String)
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Add your Azure key to Config/Secrets.plist."
        case .badResponse(let status, _): "Transcription failed (\(status))."
        case .emptyTranscript: "Didn't catch any words."
        }
    }
}

/// Azure OpenAI speech-to-text, used to turn a dictated clip into chat-box text.
enum Transcriber {
    static func transcribe(fileURL: URL, config: AzureConfig) async throws -> String {
        guard let endpoint = config.transcriptionsURL else { throw TranscriberError.notConfigured }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(config.apiKey, forHTTPHeaderField: "api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        field("model", config.transcribeDeployment)
        field("response_format", "json")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
        body.append("Content-Type: audio/mp4\r\n\r\n")
        body.append(try Data(contentsOf: fileURL))
        body.append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw TranscriberError.badResponse(
                status: status, body: String(data: data, encoding: .utf8) ?? "")
        }

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let text = (json?["text"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { throw TranscriberError.emptyTranscript }
        return text
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}
