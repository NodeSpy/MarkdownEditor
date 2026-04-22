# Project: MarkdownEditor

> macOS Native Application — Swift / SwiftUI / AppKit

## Agent Role

You are operating as a **senior macOS Swift engineer** on this project. All code you produce must be production-ready, fully implemented, and deployable. Never write stubs, TODOs, or placeholder logic unless the task explicitly scopes to a skeleton.

---

## Project Overview

-   **App Type**: Document-Based App (Markdown editor with live preview)
-   **macOS Target**: 14.0+ (Sonoma)
-   **Distribution**: Direct (SPM executable)
-   **Swift Version**: 5.9+
-   **Build System**: Swift Package Manager (`Package.swift`)

---

## Architecture

-   **Pattern**: MVVM (SwiftUI)
-   **Concurrency**: Swift Concurrency preferred (`async/await`, `actor`); legacy `DispatchQueue` usage exists in `SFTPService` and `ExportService`
-   **UI Layer**: SwiftUI-first; `WKWebView` (via `EditorWebView`) powers the Markdown editor/preview engine
-   **Document Layer**: `ReferenceFileDocument` (`MarkdownDocument`) — no SwiftData or Core Data
-   **Preferences**: `@AppStorage` via `AppSettings` singleton
-   **Secrets/Auth**: SSH key paths stored in user preferences; no Keychain usage currently

### Folder Structure

```
Sources/MarkdownEditor/
  App/              # Entry point (MarkdownEditorApp), menu commands (AppCommands)
  Views/            # SwiftUI views + EditorWebView (WKWebView bridge)
  ViewModels/       # EditorViewModel, FileTreeViewModel, RemoteFileTreeViewModel
  Models/           # MarkdownDocument, AppSettings, HeadingItem
  Services/         # ExportService, SFTPService, ThemeManager
  Resources/        # Web assets — editor.html, editor.css, editor.js
```

### Key Architectural Decisions

-   The editor engine runs entirely in a `WKWebView`. Swift communicates with JS via `evaluateJavaScript` (Swift→JS) and `WKScriptMessageHandler` (JS→Swift). All JS APIs live on `window.editorAPI`.
-   `EditorViewModel` is the bridge between the WebView and SwiftUI — it owns the `WKWebView` reference and translates JS messages into `@Published` properties.
-   Remote file editing uses SSH/SCP via `Process` invocations in `SFTPService`, not a networking library.
-   PDF export renders HTML in an offscreen `WKWebView` and prints via `NSPrintOperation`.

---

## Critical Rules

### Code Quality

-   ViewModels use `ObservableObject` with `@Published` properties
-   Typed errors where defined — `enum SFTPError: LocalizedError`, extend this pattern for new error domains
-   `[weak self]` in every closure with potential retain cycle
-   Explicit access control on every declaration
-   `///` doc comments on all public/internal interfaces
-   Never: `try!`, `!` force unwrap, empty `catch {}`, `DispatchQueue.main.async` in new code (use `@MainActor`)

### macOS Platform

-   Semantic colors only — no hardcoded hex or `NSColor(red:green:blue:)` in SwiftUI views
-   All UI elements must be accessible (`.accessibilityLabel`, `.accessibilityRole`)
-   Keyboard shortcuts exist for all primary actions (see `AppCommands.swift`) — maintain this when adding features
-   `#available(macOS 15, *)` guards for Sequoia+ APIs

### WebView / JS Bridge

-   All JS calls go through `EditorViewModel.evaluate(_:)` — never call `webView.evaluateJavaScript` directly from views
-   JSON-encode any user content before injecting into JS to prevent injection issues
-   JS→Swift messages arrive via `handleMessage(_:)` on `EditorViewModel` — add new message types there

### Git & Files

-   One logical change per commit
-   Never modify files outside the scope of the requested task without flagging it

---

## Dependencies (SPM)

None — the project uses only system frameworks (SwiftUI, WebKit, UniformTypeIdentifiers, Combine).

---

## Common Workflows

### Adding a New Feature

1.  Create view in `Views/`, ViewModel in `ViewModels/` if stateful
2.  ViewModel must be `ObservableObject` with `@Published` properties
3.  Wire into `ContentView` or `AppCommands` as appropriate
4.  If it requires a new JS editor API, add to `Resources/editor.js` under `window.editorAPI` and bridge through `EditorViewModel`

### Adding an Editor Command

1.  Add a `Button` with `.keyboardShortcut` in `AppCommands.swift`
2.  Add the corresponding method on `EditorViewModel` that calls into JS
3.  Implement the JS handler in `editor.js` under `window.editorAPI`

### Adding a New Theme

1.  Add a case to `AppTheme` in `AppSettings.swift`
2.  Add a `ThemeInfo` entry in `ThemeManager.swift`
3.  Implement the CSS variables in `editor.css`

### Adding an Export Format

1.  Add a static method on `ExportService` following the `exportHTML`/`exportPDF` pattern
2.  Add a menu command in `AppCommands.swift` with a `Notification.Name`
3.  Wire the notification in `ContentView`

---

## Testing Requirements

-   Unit test all ViewModels and Services
-   Use `Swift Testing` framework (Xcode 16+) for new tests
-   Mock services via protocol substitution
-   UI tests for critical user flows via XCUITest

---

## Build & Run

```
bash# Build (debug)
swift build

# Build (release)
swift build -c release

# Run
swift run

# Open in Xcode (for debugging)
open Package.swift
```

---

## Do Not Touch

-   `Resources/editor.html` structure — the JS bridge depends on specific element IDs
-   `MarkdownDocument.readableContentTypes` / `writableContentTypes` — changing these breaks file association