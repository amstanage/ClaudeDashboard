# File Embedding & Rich Content Rendering

## Overview

Add rich content rendering to the Claude Dashboard chat window: markdown formatting, syntax-highlighted code blocks, clickable file references with inline preview, image/PDF embedding, and drag-and-drop file attachments on outgoing messages.

**Approach:** Hybrid native SwiftUI with targeted `NSViewRepresentable` wrappers. Parse message content into typed blocks, render each with the appropriate native view, and use AppKit wrappers only for syntax-highlighted code (`NSTextView`) and PDFs (`PDFView`).

---

## Section 1: Content Parsing Layer

A parser that takes a raw message `String` and produces an array of typed content blocks, replacing the current single `Text()` rendering.

**New file:** `Services/ContentParser.swift`

### MessageBlock Enum

Named `MessageBlock` (not `ContentBlock`) to avoid collision with the existing `CLIEvent.ContentBlock`.

```swift
enum MessageBlock {
    case text(AttributedString)
    case inlineCode(String)
    case codeBlock(language: String?, code: String)
    case fileReference(path: String)
    case image(url: URL)

    /// Stable identity derived from content, not random UUIDs.
    /// Prevents unnecessary SwiftUI view recreation on re-render.
    var id: String {
        switch self {
        case .text(let s): return "text-\(s.hashValue)"
        case .inlineCode(let s): return "inline-\(s.hashValue)"
        case .codeBlock(let lang, let code): return "code-\(lang ?? "")-\(code.hashValue)"
        case .fileReference(let path): return "file-\(path)"
        case .image(let url): return "img-\(url.absoluteString)"
        }
    }
}
```

### Parsing Strategy

- Regex-based parser that walks the string sequentially
- Fenced code blocks (`` ```lang ... ``` ``) are extracted first as `.codeBlock`
- Inline code (`` `code` ``) is extracted as `.inlineCode`
- **File path detection:**
  - Absolute paths: `/path/to/file.ext` (must contain at least one `/` separator and a file extension)
  - Relative paths: `./path/to/file.ext` or `../path/to/file.ext` (must have a file extension to avoid false positives on bare `../` in prose)
  - File existence is **not** checked during parsing — deferred to `FileReferenceView` at render time to avoid synchronous filesystem calls on the main thread during layout
- Image URLs (`.png`, `.jpg`, `.gif`, `.svg`, `.webp`) are detected as `.image`
- Remaining text segments are parsed into `AttributedString` with markdown support (bold, italic, links, lists, blockquotes)
- Unsupported languages in code blocks fall back to plain monospaced text (no highlighting)

### Example

```
"Here's the fix:\n```swift\nlet x = 1\n```\nSee `/src/App.swift` for details."

Parses to:
[
    .text("Here's the fix:"),
    .codeBlock(language: "swift", code: "let x = 1"),
    .text("See "),
    .fileReference(path: "/src/App.swift"),
    .text(" for details.")
]
```

---

## Section 2: ChatMessage Model Changes

Extend `ChatMessage` to support file attachments on outgoing messages.

### FileAttachment Model

**New file:** `Models/FileAttachment.swift`

```swift
struct FileAttachment: Identifiable, Equatable, Hashable {
    let id: UUID
    let url: URL
    let fileName: String
    let fileType: FileType
    let fileSize: Int64

    /// Thumbnail image data for previews (PNG-encoded).
    /// Stored as Data instead of NSImage for Equatable/Hashable/Sendable conformance.
    let thumbnailData: Data?

    enum FileType: Equatable, Hashable {
        case image, pdf, code, text, other
    }

    /// Convenience: decode thumbnailData into NSImage for display.
    var thumbnail: NSImage? {
        thumbnailData.flatMap { NSImage(data: $0) }
    }

    static func == (lhs: FileAttachment, rhs: FileAttachment) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

### ChatMessage Changes

```swift
struct ChatMessage: Identifiable {
    // ... existing fields unchanged ...
    var attachments: [FileAttachment]  // new, defaults to []
}
```

- `FileType` is determined from the file extension at attach time
- Thumbnails are generated lazily for images only, stored as PNG `Data` for `Sendable`/`Equatable` safety
- Attachments live on the `ChatMessage` for display in the bubble and passing to the CLI
- Parsed `MessageBlock`s from Section 1 are computed at render time by the view, not stored on the model

---

## Section 3: Rich Message Rendering

Replace the current `MessageBubbleView` content area with a block-based renderer. Bubble structure (alignment, glass effect, token count) is unchanged.

### New Files

**`Views/Chat/MessageContentView.swift`**
- Takes raw `content: String`, calls `ContentParser.parse()`, renders each block with the appropriate view
- Blocks stack vertically inside the existing bubble
- Handles `.text` → `Text(attributedString)`, `.codeBlock` → `CodeBlockView`, `.fileReference` → `FileReferenceView`, `.image` → inline `Image`, `.inlineCode` → styled `Text`

**`Views/Chat/CodeBlockView.swift`**
- `NSViewRepresentable` wrapping `NSTextView` (read-only, no scroll view, sized to content)
- Syntax highlighting via lightweight token-based colorizer (keyword/string/comment/number detection for common languages)
- Supported languages: Swift, Python, JavaScript, TypeScript, Go, Rust, shell, JSON, YAML, HTML, CSS, SQL, C/C++, Java, Kotlin, Ruby. Unsupported languages fall back to plain monospaced text.
- Copy button overlay in top-right corner
- Language label in top-left corner
- Dark background to visually distinguish from prose
- **Known complexity:** `NSTextView` sizing inside `NSViewRepresentable` in a `LazyVStack` requires careful `intrinsicContentSize` handling. Highlighting is computed once on appearance and cached, not recomputed on every SwiftUI layout pass.

### MessageBubbleView Changes

`MessageBubbleView` becomes a thin wrapper: bubble chrome (glass effect, alignment, token count) + `MessageContentView` inside. The `.if` conditional modifier and role-based styling remain.

Attachments are rendered as a separate row of chips above the message content — intentionally outside the `MessageBlock` parsing pipeline. Attachments are structured data on the model, not parsed from text, so they follow a different rendering path.

---

## Section 4: File Path Detection & Preview

When `ContentParser` detects a file path, it emits `.fileReference(path)`. The renderer shows it as a tappable chip.

**New file:** `Views/Chat/FileReferenceView.swift`

### Rendering

- Inline tappable chip styled as a pill: file icon + filename + extension badge
- On click: expands to show file contents inline in the chat bubble (collapsible)
- Expand/collapse state is local to the view (no model changes)
- File existence check happens here (at render time), not during parsing
- If file does not exist, chip renders as non-interactive plain text

### File Type Handling

| File Type | Preview Behavior |
|-----------|-----------------|
| Code files (.swift, .py, .js, .ts, etc.) | `CodeBlockView` with syntax highlighting |
| Images (.png, .jpg, .gif, .svg) | Inline preview scaled to fit, max ~400px wide |
| PDFs (.pdf) | First page via `PDFKit.PDFView` in `NSViewRepresentable` |
| Other files | Metadata (size, modified date) + "Open in Finder" button |

---

## Section 5: Drag-and-Drop Attachments & CLI Integration

### Input Side (MessageInputView changes)

- `.onDrop(of: [.fileURL])` modifier on the enclosing `HStack`, not the `TextField` directly (avoids interfering with text drag-and-drop)
- Paperclip button next to the send button opens `NSOpenPanel` for file picking
- Attached files shown as a horizontal row of thumbnail chips above the text field
- Each chip: file icon/thumbnail, filename, file size, removable with X button
- Attachments stored on `ChatViewModel` as a temporary array until send

### Limits

- Maximum 10 files per message
- Maximum 1MB per file, 5MB total per message
- Binary/non-UTF-8 files are rejected with user-facing error ("This file type is not supported")
- Files that fail to read (permissions, etc.) show an error chip with the reason

### Sending (ChatViewModel changes)

- `sendMessage()` reads file contents **asynchronously on a background task** before composing the message string, to avoid blocking the main thread
- Populates the user `ChatMessage.attachments` array from the pending attachments
- Clears pending attachments after send
- Passes the composed string (with file contents prepended) to `CLIService.sendMessage()` — no signature change needed on `CLIService`

### CLI Integration

- `ChatViewModel` reads attachment file contents and prepends them to the message text as code blocks
- Format: `` ```filename.swift\n<file contents>\n``` ``
- This works with `claude --print` today without special flags
- `CLIService.sendMessage()` signature is unchanged — it receives the already-composed string

### Display in Bubble

- If `message.attachments` is non-empty, render attachment chips in the message bubble
- Tapping a chip expands it inline (same expand/collapse behavior as `FileReferenceView`)

---

## Scope Notes

- **Session history replay** (`SessionDetailFullView` in `ContentView.swift`) also renders messages as plain text. Updating it to use `MessageContentView` is a natural follow-up but is **out of scope** for this phase to keep the change set focused.
- **Streaming/partial message rendering** is not currently used (messages arrive complete). If streaming is added later, the parser will need to handle incomplete markdown (unclosed code fences, etc.). Out of scope for now.
- **Accessibility:** `CodeBlockView` should set appropriate VoiceOver labels (language, "code block"), and `FileReferenceView` chips should be keyboard-navigable. These are implementation details, not design decisions.

---

## New Files Summary

| File | Purpose |
|------|---------|
| `Services/ContentParser.swift` | Parse message strings into typed `MessageBlock` array |
| `Models/FileAttachment.swift` | File attachment data model (`Equatable`, `Hashable`, `Sendable`-safe) |
| `Views/Chat/MessageContentView.swift` | Block-based message content renderer |
| `Views/Chat/CodeBlockView.swift` | Syntax-highlighted code block (`NSViewRepresentable`) |
| `Views/Chat/FileReferenceView.swift` | Clickable file reference chip with inline preview |

## Modified Files Summary

| File | Changes |
|------|---------|
| `Models/ChatMessage.swift` | Add `attachments: [FileAttachment]` field |
| `Views/Chat/MessageBubbleView.swift` | Replace `Text()` body with `MessageContentView`, add attachment chip row |
| `Views/Chat/MessageInputView.swift` | Add drag-and-drop on enclosing HStack, paperclip button, attachment chip row |
| `ViewModels/ChatViewModel.swift` | Add pending attachments array, async file reading, compose message with file contents |
