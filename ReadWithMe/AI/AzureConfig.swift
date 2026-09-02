import Foundation

/// Azure OpenAI credentials, read from a gitignored Secrets.plist in the bundle.
/// Copy Config/Secrets.example.plist to Config/Secrets.plist and fill it in.
struct AzureConfig {
    let baseURL: String
    let apiVersion: String
    let apiKey: String
    /// Chat deployment used to answer questions about the document (e.g. gpt-5.6-sol).
    let chatDeployment: String
    /// Speech-to-text deployment used for dictation (e.g. gpt-4o-transcribe).
    let transcribeDeployment: String

    /// Development-only fallback: a gitignored Secrets.plist may be present in the
    /// bundle. Shipped builds contain no such file, so users configure their own
    /// credentials through Settings (stored in the Keychain).
    static func loadFromBundle(bundle: Bundle = .main) -> AzureConfig? {
        guard let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization
                  .propertyList(from: data, format: nil) as? [String: String],
              let baseURL = plist["AZURE_OPENAI_BASE_URL"], !baseURL.isEmpty,
              let apiKey = plist["AZURE_OPENAI_API_KEY"], !apiKey.isEmpty
        else { return nil }
        return AzureConfig(
            baseURL: baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL,
            apiVersion: plist["AZURE_OPENAI_API_VERSION"] ?? "2025-04-01-preview",
            apiKey: apiKey,
            chatDeployment: plist["AZURE_OPENAI_CHAT_DEPLOYMENT"] ?? "",
            transcribeDeployment: plist["AZURE_OPENAI_TRANSCRIBE_DEPLOYMENT"] ?? "gpt-4o-transcribe")
    }

    var chatCompletionsURL: URL? {
        guard !chatDeployment.isEmpty else { return nil }
        return URL(string: "\(baseURL)/deployments/\(chatDeployment)/chat/completions?api-version=\(apiVersion)")
    }

    var transcriptionsURL: URL? {
        URL(string: "\(baseURL)/deployments/\(transcribeDeployment)/audio/transcriptions?api-version=\(apiVersion)")
    }
}
