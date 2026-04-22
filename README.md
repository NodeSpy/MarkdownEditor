# MarkdownEditor

A full-featured, Typora-inspired WYSIWYG Markdown editor built as a native macOS app with Swift/SwiftUI.

## Features

- **WYSIWYG & Source dual-mode editing** — seamless live preview or raw Markdown with syntax highlighting
- **Rich Markdown rendering** — headers, bold, italic, strikethrough, links, images, blockquotes, tables, task lists
- **Code blocks** — syntax highlighted via highlight.js with 100+ language support
- **Math** — inline and block LaTeX via KaTeX
- **Diagrams** — Mermaid flowcharts, sequence diagrams, Gantt charts
- **File tree sidebar** — browse and open files from any directory
- **Outline panel** — auto-generated from document headings with click-to-navigate
- **Multiple themes** — Light, Dark, GitHub, Solarized with CSS variable-based theming
- **Export** — PDF and HTML export
- **Focus mode** — dims all paragraphs except the current one
- **Typewriter mode** — keeps the active line vertically centered
- **Native macOS integration** — menus, keyboard shortcuts, document-based architecture

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+

## Build & Run

```bash
cd MarkdownEditor
swift build
swift run
```

Or open `Package.swift` in Xcode for a full IDE experience.

## Architecture

- **SwiftUI** app shell with `DocumentGroup` for native file handling
- **WKWebView** hybrid editor with embedded HTML/CSS/JS for WYSIWYG Markdown editing
- **markdown-it** for Markdown parsing, **highlight.js** for code, **KaTeX** for math, **mermaid** for diagrams
- Bidirectional Swift ↔ JS communication via `WKScriptMessageHandler` and `evaluateJavaScript()`
