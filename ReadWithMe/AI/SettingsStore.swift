import Foundation
import Combine

/// User-supplied Azure OpenAI configuration. Non-secret fields live in
/// UserDefaults; the API key lives in the Keychain. On first launch nothing is
/// set, so the app shows the settings sheet and the user enters their own key.
///
/// For local development you may still drop a gitignored Config/Secrets.plist in
/// the bundle — it is used only as a fallback when nothing has been saved.
@MainActor
final class SettingsStore: ObservableObject {
    @Published var baseURL: String
    @Published var apiKey: String
    @Published var chatDeployment: String
    @Published var transcribeDeployment: String
    @Published var apiVersion: String

    /// Shared instance used across the app so the Settings window, the chat, and
    /// the transcriber all read and write the same configuration.
    static let shared = SettingsStore()

    private static let keyAccount = "AZURE_OPENAI_API_KEY"
    private let defaults = UserDefaults.standard

    init() {
        let bundled = AzureConfig.loadFromBundle()
        baseURL = defaults.string(forKey: "baseURL") ?? bundled?.baseURL ?? ""
        chatDeployment = defaults.string(forKey: "chatDeployment") ?? bundled?.chatDeployment ?? "gpt-5.6-sol"
        transcribeDeployment = defaults.string(forKey: "transcribeDeployment") ?? bundled?.transcribeDeployment ?? "gpt-4o-transcribe"
        apiVersion = defaults.string(forKey: "apiVersion") ?? bundled?.apiVersion ?? "2025-04-01-preview"
        apiKey = Keychain.get(account: Self.keyAccount) ?? bundled?.apiKey ?? ""
    }

    func save() {
        defaults.set(baseURL.trimmingCharacters(in: .whitespaces), forKey: "baseURL")
        defaults.set(chatDeployment.trimmingCharacters(in: .whitespaces), forKey: "chatDeployment")
        defaults.set(transcribeDeployment.trimmingCharacters(in: .whitespaces), forKey: "transcribeDeployment")
        defaults.set(apiVersion.trimmingCharacters(in: .whitespaces), forKey: "apiVersion")
        Keychain.set(apiKey.trimmingCharacters(in: .whitespaces), account: Self.keyAccount)
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty &&
        !chatDeployment.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var azureConfig: AzureConfig? {
        guard isConfigured else { return nil }
        let base = baseURL.trimmingCharacters(in: .whitespaces)
        return AzureConfig(
            baseURL: base.hasSuffix("/") ? String(base.dropLast()) : base,
            apiVersion: apiVersion.trimmingCharacters(in: .whitespaces),
            apiKey: apiKey.trimmingCharacters(in: .whitespaces),
            chatDeployment: chatDeployment.trimmingCharacters(in: .whitespaces),
            transcribeDeployment: transcribeDeployment.trimmingCharacters(in: .whitespaces))
    }
}
