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

## Install

### Homebrew (recommended)

```sh
brew tap kshah00/tap
brew install --cask --no-quarantine read-with-me
```

`--no-quarantine` lets the app launch without a Gatekeeper prompt — it is
Developer ID–signed but not notarized. If Homebrew asks you to trust the tap,
run `brew trust kshah00/tap` first.

### Manual (DMG)

Download the signed DMG from the
[latest release](https://github.com/kshah00/read-with-me/releases/latest),
open it, and drag **ReadWithMe** to Applications. On first launch, right-click
the app → **Open** (or run `xattr -dr com.apple.quarantine /Applications/ReadWithMe.app`).

## First run — bring your own key

ReadWithMe ships with **no credentials**. On first launch it opens Settings
(⌘,) where you enter your own **Azure OpenAI** endpoint, API key, and deployment
names. The API key is stored in the **macOS Keychain**; everything else in
`UserDefaults`. Nothing is written to the app bundle, and the key never leaves
your Mac except to call your own endpoint.

## Build from source

```sh
xcodegen generate
xcodebuild -project ReadWithMe.xcodeproj -scheme ReadWithMe -configuration Debug build
open "$(xcodebuild -project ReadWithMe.xcodeproj -scheme ReadWithMe -showBuildSettings 2>/dev/null | awk -F'= ' '/ BUILT_PRODUCTS_DIR /{print $2}')/ReadWithMe.app"
```

Or just open `ReadWithMe.xcodeproj` in Xcode and hit Run.

## Configuration

Enter your Azure OpenAI credentials in-app via **Settings (⌘,)** — the key is
stored in the Keychain. (For local development you may optionally drop a
gitignored `Config/Secrets.plist`, copied from `Secrets.example.plist`, and add
it to the app target; it is used only as a fallback and never committed.)

## Using it

- **Open** (toolbar) to pick a PDF.
- Select text and click **Highlight** to annotate it in yellow.
- Type in the side panel, or tap the **mic** to dictate a question.
- Answers stream in and cite page numbers.
