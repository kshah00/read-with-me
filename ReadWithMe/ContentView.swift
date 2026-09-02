import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @StateObject private var doc = PDFDocumentModel()
    @StateObject private var chat: ChatViewModel
    @State private var showChat = true
    @State private var showSettings = false

    init() {
        let model = PDFDocumentModel()
        _doc = StateObject(wrappedValue: model)
        // ChatViewModel is rebuilt against the shared settings store on first use;
        // it reads live config from the store at send-time.
        _chat = StateObject(wrappedValue: ChatViewModel(doc: model, settings: SettingsStore.shared))
    }

    var body: some View {
        HSplitView {
            pdfPane
                .frame(minWidth: 480)
            if showChat {
                ChatView(chat: chat)
                    .frame(minWidth: 300, idealWidth: 360, maxWidth: 560)
            }
        }
        .toolbar { toolbarContent }
        .navigationTitle(doc.documentTitle)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(settings)
        }
        .onAppear {
            if !settings.isConfigured { showSettings = true }
        }
    }

    // MARK: - PDF pane

    private var pdfPane: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor).ignoresSafeArea()
            if doc.document != nil {
                PDFViewerView(model: doc)
            } else {
                emptyReader
            }
            if doc.isIndexing {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Indexing document for AI context…")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var emptyReader: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.secondary)
            Text("Open a PDF to start reading")
                .font(.system(size: 15, weight: .medium))
            Button("Open PDF…") { openPDF() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                openPDF()
            } label: {
                Label("Open", systemImage: "folder")
            }
            .help("Open a PDF")
        }

        ToolbarItemGroup(placement: .principal) {
            if doc.document != nil {
                Button {
                    doc.goToPage(max(0, doc.currentPageIndex - 1))
                } label: { Image(systemName: "chevron.up") }
                    .disabled(doc.currentPageIndex <= 0)
                Text("\(doc.currentPageIndex + 1) / \(doc.pageCount)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                Button {
                    doc.goToPage(min(doc.pageCount - 1, doc.currentPageIndex + 1))
                } label: { Image(systemName: "chevron.down") }
                    .disabled(doc.currentPageIndex >= doc.pageCount - 1)

                Divider()

                Button {
                    doc.highlightSelection()
                } label: { Label("Highlight", systemImage: "highlighter") }
                    .disabled(doc.currentSelection.isEmpty)
                    .help("Highlight selected text")
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .help("AI configuration")
            Button {
                withAnimation { showChat.toggle() }
            } label: {
                Label("Chat", systemImage: showChat ? "sidebar.right" : "bubble.left.and.bubble.right")
            }
            .help("Toggle chat panel")
        }
    }

    // MARK: - Actions

    private func openPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            doc.open(url: url)
        }
    }
}
