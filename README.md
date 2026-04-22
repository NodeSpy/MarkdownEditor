# MarkdownEditor

A full-featured, Typora-inspired WYSIWYG Markdown editor built as a native macOS app with Swift/SwiftUI and a WKWebView-powered editing engine.

**Requirements:** macOS 14.0 (Sonoma) or later · Swift 5.9+

---

## Features

### Editor Modes

| Mode | Description |
|------|-------------|
| **WYSIWYG (Preview)** | True inline rendering — Markdown syntax converts to formatted elements as you type |
| **Source** | Plain-text Markdown editing with clean spacing |

Toggle between modes with **⌥⌘P** or the status bar button.

### Markdown Support

- Headings H1–H6 (type `# ` and the heading renders immediately)
- Bold, italic, strikethrough, inline code, links, images
- Blockquotes, horizontal rules
- Ordered, unordered, and task lists with auto-continuation on Enter
- Tables
- Fenced code blocks with automatic language detection

### Extended Syntax

- **Math** — inline (`$...$`) and block (`$$...$$`) LaTeX via [KaTeX](https://katex.org)
- **Diagrams** — Mermaid flowcharts, sequence diagrams, and Gantt charts
- **Syntax highlighting** — 100+ languages via [highlight.js](https://highlightjs.org)

### Writing Modes

- **Focus Mode** (`⌥⌘F`) — dims all paragraphs except the one being edited
- **Typewriter Mode** (`⌥⌘T`) — keeps the active line vertically centered as you type

### Sidebar Panels

- **Files** — local directory tree browser; opens any `.md` or `.txt` file with a click
- **Remote** — SFTP file browser with breadcrumb navigation, back/forward history, and live editing over SSH
- **Outline** — live document outline extracted from headings; click any entry to jump there

### Themes

Four themes switchable at runtime from the status bar or Preferences:

| Theme | Description |
|-------|-------------|
| Light | Clean, bright default |
| Dark | Tokyo Night–inspired with purple accents |
| GitHub | Familiar GitHub rendering |
| Solarized | Ethan Schoonover's precision color palette |

### Export

- **HTML** (`⇧⌘E`) — self-contained document with embedded styles and CDN-linked libraries
- **PDF** (`⇧⌘P`) — professional typesetting via `NSPrintOperation` with custom margins, heading hierarchy, styled code blocks, and alternating table rows

### Remote Editing (SFTP)

Connect to any SSH server with key-based authentication:

- **Connect** (`⇧⌘O`) — host, port, username, SSH key path, starting directory
- Browse the remote file tree, open `.md` files directly into the editor
- **Save to Remote** (`⇧⌘U`) — pushes edits back via SSH without leaving the app
- Connection pooling via `ControlPersist` for fast repeated operations

### Native macOS Integration

- `DocumentGroup`-based document architecture (`.md`, `.markdown`, `.txt`)
- Full menu bar with keyboard shortcuts for every formatting action
- Preferences window (font size 12–24 px, default mode, theme, sidebar options)
- Semantic colors throughout — adapts to system light/dark mode automatically

---

## Keyboard Shortcuts

### Text Formatting

| Action | Shortcut |
|--------|----------|
| Bold | `⌘B` |
| Italic | `⌘I` |
| Strikethrough | `⌘⇧X` |
| Inline Code | `⌘⇧C` |
| Insert Link | `⌘K` |

### Block Formatting

| Action | Shortcut |
|--------|----------|
| Heading 1–4 | `⌘1` – `⌘4` |
| Blockquote | `⌘⇧.` |
| Code Block | `⌘⇧K` |
| Math Block | `⌘⇧M` |
| Bullet List | `⌘⇧L` |
| Numbered List | `⌘⇧O` |
| Task List | `⌘⇧T` |
| Table | `⌘⇧D` |
| Horizontal Rule | `⌘⇧H` |

### View & Remote

| Action | Shortcut |
|--------|----------|
| Toggle Preview/Source | `⌥⌘P` |
| Focus Mode | `⌥⌘F` |
| Typewriter Mode | `⌥⌘T` |
| Connect to Remote | `⇧⌘O` |
| Save to Remote | `⇧⌘U` |
| Export HTML | `⇧⌘E` |
| Export PDF | `⇧⌘P` |

---

## Build & Run

```bash
# Clone and navigate
cd macos_utilities/apps/MarkdownEditor

# Debug build
swift build

# Run
swift run

# Release build
swift build -c release

# Open in Xcode
open Package.swift
```

No external Swift dependencies — the package uses only system frameworks (SwiftUI, WebKit, UniformTypeIdentifiers, Combine). The editor libraries (markdown-it, KaTeX, highlight.js, Mermaid, Turndown) are loaded from CDN in the embedded WebView.

---

## Architecture

```
Sources/MarkdownEditor/
├── App/            # Entry point (MarkdownEditorApp), menu commands (AppCommands)
├── Models/         # MarkdownDocument (ReferenceFileDocument), AppSettings, HeadingItem
├── Services/       # ExportService, SFTPService, ThemeManager
├── ViewModels/     # EditorViewModel, FileTreeViewModel, RemoteFileTreeViewModel
├── Views/          # ContentView, EditorWebView, sidebar panels, preferences
└── Resources/      # editor.html, editor.css, editor.js
```

### Swift ↔ JavaScript Bridge

The editor engine runs entirely inside a `WKWebView`. Communication is bidirectional:

- **Swift → JS:** `EditorViewModel.evaluate(_:)` calls `window.editorAPI` methods (set content, apply formatting, switch theme, etc.)
- **JS → Swift:** the web layer posts JSON messages on the `editorBridge` handler; `EditorViewModel.handleMessage(_:)` dispatches them to `@Published` properties

Message types: `ready`, `contentChanged`, `headings`, `wordCount`, `modeChanged`, `save`, `openLink`.

### Key Components

| Component | Role |
|-----------|------|
| `MarkdownDocument` | `ReferenceFileDocument` — owns file I/O and the raw Markdown string |
| `EditorViewModel` | `@MainActor` ObservableObject — owns `WKWebView`, bridges JS messages to SwiftUI state |
| `AppSettings` | Singleton backed by `@AppStorage` — persists theme, font size, modes, sidebar state |
| `SFTPService` | Shells out to `/usr/bin/ssh` for remote file operations |
| `ExportService` | HTML wrapping + `NSPrintOperation` PDF rendering |
| `ThemeManager` | Theme metadata (labels, descriptions, preview colors) |
| `editor.js` | ~1000-line WYSIWYG engine — inline pattern detection, mode switching, bridge messaging |
| `editor.css` | CSS custom-property–based theming for all four themes |
