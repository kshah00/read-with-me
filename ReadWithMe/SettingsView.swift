import SwiftUI

/// Where users enter their own Azure OpenAI credentials. The API key is stored in
/// the Keychain; everything else in UserDefaults. Nothing ships with the app.
struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var showKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill").foregroundStyle(.tint)
                Text("AI Configuration").font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 4)

            Text("ReadWithMe uses your own Azure OpenAI resource. Your API key is stored securely in the macOS Keychain and never leaves your Mac except to call your endpoint.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20).padding(.bottom, 12)

            Form {
                field("Endpoint base URL", text: $settings.baseURL,
                      placeholder: "https://YOUR-RESOURCE.cognitiveservices.azure.com/openai")
                apiKeyField
                field("Chat deployment", text: $settings.chatDeployment, placeholder: "gpt-5.6-sol")
                field("Transcribe deployment", text: $settings.transcribeDeployment, placeholder: "gpt-4o-transcribe")
                field("API version", text: $settings.apiVersion, placeholder: "2025-04-01-preview")
            }
            .formStyle(.grouped)

            HStack {
                Link("How to get these", destination: URL(string: "https://learn.microsoft.com/azure/ai-services/openai/quickstart")!)
                    .font(.system(size: 11))
                Spacer()
                Button("Save") {
                    settings.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!settings.isConfigured)
            }
            .padding(20)
        }
        .frame(width: 460)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .autocorrectionDisabled()
        }
    }

    private var apiKeyField: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("API key").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Group {
                    if showKey {
                        TextField("Your Azure OpenAI API key", text: $settings.apiKey)
                    } else {
                        SecureField("Your Azure OpenAI API key", text: $settings.apiKey)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .autocorrectionDisabled()
                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(showKey ? "Hide key" : "Show key")
            }
        }
    }
}
