import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var markdownText: UTType {
        UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
    }
}

final class MarkdownDocument: ReferenceFileDocument {
    typealias Snapshot = String

    @Published var text: String

    static var readableContentTypes: [UTType] {
        [.markdownText, .plainText]
    }

    static var writableContentTypes: [UTType] {
        [.markdownText, .plainText]
    }

    init(text: String = MarkdownDocument.welcomeText) {
        self.text = text
    }

    static let welcomeText: String = """
    # Welcome to MarkdownEditor

    A beautiful, full-featured Markdown editor for macOS.

    ## Features

    **Bold**, *italic*, ~~strikethrough~~, and `inline code` all render live.

    ### Links & Images

    Visit [Apple](https://apple.com) or check out the [SwiftUI docs](https://developer.apple.com/xcode/swiftui/).

    ### Lists

    - Bullet list item one
    - Bullet list item two
      - Nested item
    - Bullet list item three

    1. Numbered list
    2. Second item
    3. Third item

    ### Task Lists

    - [x] Build the editor engine
    - [x] Add syntax highlighting
    - [ ] Ship version 1.0
    - [ ] Take over the world

    ### Blockquotes

    > "Simplicity is the ultimate sophistication."
    > — Leonardo da Vinci

    ### Code Blocks

    ```swift
    struct ContentView: View {
        var body: some View {
            Text("Hello, Markdown!")
                .font(.largeTitle)
        }
    }
    ```

    ### Tables

    | Feature       | Status |
    |---------------|--------|
    | Preview       | Done   |
    | Source Mode    | Done   |
    | Math (KaTeX)  | Done   |
    | Mermaid        | Done   |
    | Export PDF     | Done   |

    ### Math (KaTeX)

    Inline math: $E = mc^2$

    Block math:

    $$
    \\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}
    $$

    ### Diagrams (Mermaid)

    ```mermaid
    graph LR
        A[Write Markdown] --> B[Live Preview]
        B --> C[Export PDF]
        B --> D[Export HTML]
    ```

    ---

    *Start editing to see the magic happen!*
    """

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }

    func snapshot(contentType: UTType) throws -> String {
        return text
    }

    func fileWrapper(snapshot: String, configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = snapshot.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
