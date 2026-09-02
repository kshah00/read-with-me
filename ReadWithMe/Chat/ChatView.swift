import SwiftUI

struct ChatView: View {
    @ObservedObject var chat: ChatViewModel
    @EnvironmentObject var settings: SettingsStore
    @StateObject private var recorder = AudioRecorder()
    @State private var isTranscribing = false
    @FocusState private var inputFocused: Bool

    private var config: AzureConfig? { settings.azureConfig }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            messageList
            composer
        }
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
            Text("Ask about this document")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button {
                chat.clear()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Clear conversation")
            .disabled(chat.messages.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if chat.messages.isEmpty {
                        emptyState
                    }
                    ForEach(chat.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(14)
            }
            .onChange(of: chat.messages.last?.text) { _, _ in
                if let last = chat.messages.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open a PDF and ask me anything")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            ForEach(["Summarize this page", "Explain the highlighted part", "What does this section conclude?"], id: \.self) { s in
                Button {
                    chat.input = s
                    chat.send()
                } label: {
                    Text(s)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 40)
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if let err = chat.errorText {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 8) {
                micButton
                TextField("Message", text: $chat.input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .focused($inputFocused)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .onSubmit { chat.send() }
                Button {
                    chat.send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(chat.input.isEmpty ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(chat.input.trimmingCharacters(in: .whitespaces).isEmpty || chat.isResponding)
            }
        }
        .padding(12)
    }

    private var micButton: some View {
        Button {
            Task { await toggleDictation() }
        } label: {
            Image(systemName: isTranscribing ? "waveform" : (recorder.isRecording ? "stop.circle.fill" : "mic.fill"))
                .font(.system(size: 20))
                .foregroundStyle(recorder.isRecording ? Color.red : Color.secondary)
                .symbolEffect(.pulse, isActive: recorder.isRecording || isTranscribing)
        }
        .buttonStyle(.plain)
        .help(recorder.isRecording ? "Stop and transcribe" : "Dictate a question")
        .disabled(isTranscribing || config?.transcriptionsURL == nil)
    }

    private func toggleDictation() async {
        if recorder.isRecording {
            guard let url = recorder.stop(), let config else { return }
            isTranscribing = true
            defer { isTranscribing = false }
            do {
                let text = try await Transcriber.transcribe(fileURL: url, config: config)
                chat.input = chat.input.isEmpty ? text : chat.input + " " + text
                inputFocused = true
            } catch {
                chat.errorText = error.localizedDescription
            }
        } else {
            let ok = await recorder.start()
            if !ok { chat.errorText = "Microphone access was denied." }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 24) }
            VStack(alignment: .leading, spacing: 4) {
                if message.role == .user {
                    Text(message.text)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .foregroundStyle(Color.white)
                } else if message.text.isEmpty && message.isStreaming {
                    Text("…").font(.system(size: 13)).foregroundStyle(.secondary)
                } else {
                    MarkdownText(markdown: message.text, textColor: .primary)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(bubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if message.role == .assistant { Spacer(minLength: 24) }
        }
    }

    @ViewBuilder private var bubbleBackground: some View {
        if message.role == .user {
            Color.accentColor
        } else {
            Color.primary.opacity(0.07)
        }
    }
}
