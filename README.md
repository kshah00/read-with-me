# ReadWithMe

A native macOS companion reader. Open a PDF, read it, highlight passages, and ask an
AI chatbot questions about what you're reading — by typing or dictating. The chatbot
has context on the page you're looking at, anything you've highlighted, and the most
relevant passages retrieved from anywhere in the document.

## Stack

- **SwiftUI + PDFKit**, macOS 14+, project generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen).
- **AI:** Azure OpenAI `gpt-5.6-sol` chat deployment, streamed token-by-token.
- **Dictation:** Azure OpenAI `gpt-4o-transcribe`.
- **Context / RAG:** per-page text is chunked and embedded **on-device** with Apple's
  `NLEmbedding` (no embeddings API, no cost), then retrieved by cosine similarity.
  The current page + any selection are always injected too.

## Layout

- `ReadWithMe/PDF/` — `PDFViewerView` (PDFKit wrapper) + `PDFDocumentModel` (open,
  current-page tracking, highlight, context assembly).
- `ReadWithMe/Chat/` — chat UI, view model, message model.
- `ReadWithMe/AI/` — `AzureConfig`, streaming `ChatClient`, `Transcriber`, `AudioRecorder`.
- `ReadWithMe/RAG/` — `DocumentIndex` (on-device chunk embedding + retrieval).

## Build & run

```sh
xcodegen generate
xcodebuild -project ReadWithMe.xcodeproj -scheme ReadWithMe -configuration Debug build
open "$(xcodebuild -project ReadWithMe.xcodeproj -scheme ReadWithMe -showBuildSettings 2>/dev/null | awk -F'= ' '/ BUILT_PRODUCTS_DIR /{print $2}')/ReadWithMe.app"
```

Or just open `ReadWithMe.xcodeproj` in Xcode and hit Run.

## Configuration

Credentials live in `Config/Secrets.plist` (gitignored). Copy `Secrets.example.plist`
to `Secrets.plist` and fill in your Azure OpenAI base URL, key, and deployment names.

## Using it

- **Open** (toolbar) to pick a PDF.
- Select text and click **Highlight** to annotate it in yellow.
- Type in the side panel, or tap the **mic** to dictate a question.
- Answers stream in and cite page numbers.
