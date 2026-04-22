import SwiftUI
import WebKit

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var headings: [HeadingItem] = []
    @Published var wordCount: Int = 0
    @Published var charCount: Int = 0
    @Published var lineCount: Int = 0
    @Published var readingTime: Int = 1
    @Published var currentMode: EditorMode = .preview
    @Published var isReady: Bool = false

    weak var webView: WKWebView?
    weak var document: MarkdownDocument?

    private var pendingContent: String?

    func setDocument(_ doc: MarkdownDocument) {
        self.document = doc
        if isReady {
            sendContentToEditor(doc.text)
        } else {
            pendingContent = doc.text
        }
    }

    // MARK: - Swift -> JS

    func sendContentToEditor(_ content: String) {
        guard let jsonData = try? JSONEncoder().encode(content),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else { return }
        evaluate("window.editorAPI.setContent(\(jsonString))")
    }

    func toggleMode() {
        evaluate("window.editorAPI.toggleMode()")
    }

    func setMode(_ mode: EditorMode) {
        currentMode = mode
        evaluate("window.editorAPI.setMode('\(mode.rawValue)')")
    }

    func setTheme(_ theme: AppTheme) {
        evaluate("window.editorAPI.setTheme('\(theme.rawValue)')")
    }

    func setFontSize(_ size: Double) {
        evaluate("window.editorAPI.setFontSize(\(Int(size)))")
    }

    func toggleFocusMode() {
        evaluate("window.editorAPI.toggleFocusMode()")
    }

    func toggleTypewriterMode() {
        evaluate("window.editorAPI.toggleTypewriterMode()")
    }

    func setFocusMode(_ enabled: Bool) {
        evaluate("window.editorAPI.setFocusMode(\(enabled))")
    }

    func setTypewriterMode(_ enabled: Bool) {
        evaluate("window.editorAPI.setTypewriterMode(\(enabled))")
    }

    func applyFormatting(_ format: String) {
        evaluate("window.editorAPI.applyFormatting('\(format)')")
    }

    func scrollToHeading(_ headingId: String) {
        evaluate("window.editorAPI.scrollToHeading('\(headingId)')")
    }

    func getHTML(completion: @escaping (Result<String, Error>) -> Void) {
        guard let webView = webView else {
            completion(.failure(EditorError.webViewUnavailable))
            return
        }
        webView.evaluateJavaScript("window.editorAPI.getHTML()") { result, error in
            if let html = result as? String {
                completion(.success(html))
            } else {
                completion(.failure(error ?? EditorError.contentRetrievalFailed))
            }
        }
    }

    func getContent(completion: @escaping (Result<String, Error>) -> Void) {
        guard let webView = webView else {
            completion(.failure(EditorError.webViewUnavailable))
            return
        }
        webView.evaluateJavaScript("window.editorAPI.getContent()") { result, error in
            if let content = result as? String {
                completion(.success(content))
            } else {
                completion(.failure(error ?? EditorError.contentRetrievalFailed))
            }
        }
    }

    // MARK: - JS -> Swift Message Handling

    nonisolated func handleMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String,
              let data = message["data"] as? [String: Any]
        else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch type {
            case "ready":
                self.isReady = true
                if let pending = self.pendingContent {
                    self.sendContentToEditor(pending)
                    self.pendingContent = nil
                } else if let doc = self.document {
                    self.sendContentToEditor(doc.text)
                }

            case "contentChanged":
                if let content = data["content"] as? String {
                    self.document?.text = content
                }

            case "headings":
                if let headingsData = data["headings"] as? [[String: Any]] {
                    self.headings = headingsData.compactMap { item in
                        guard let level = item["level"] as? Int,
                              let text = item["text"] as? String,
                              let id = item["id"] as? String
                        else { return nil }
                        return HeadingItem(id: id, level: level, text: text)
                    }
                }

            case "wordCount":
                self.wordCount = data["words"] as? Int ?? 0
                self.charCount = data["characters"] as? Int ?? 0
                self.lineCount = data["lines"] as? Int ?? 0
                self.readingTime = data["readingTime"] as? Int ?? 1

            case "modeChanged":
                if let modeStr = data["mode"] as? String,
                   let mode = EditorMode(rawValue: modeStr) {
                    self.currentMode = mode
                }

            case "save":
                // Trigger native save via notification
                NotificationCenter.default.post(name: .editorSaveRequested, object: nil)

            case "openLink":
                if let urlStr = data["url"] as? String,
                   let url = URL(string: urlStr) {
                    NSWorkspace.shared.open(url)
                }

            default:
                break
            }
        }
    }

    // MARK: - Helpers

    private func evaluate(_ js: String) {
        webView?.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("JS Error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Errors

enum EditorError: LocalizedError {
    case webViewUnavailable
    case contentRetrievalFailed

    var errorDescription: String? {
        switch self {
        case .webViewUnavailable: return "Editor web view is not available"
        case .contentRetrievalFailed: return "Failed to retrieve content from editor"
        }
    }
}

extension Notification.Name {
    static let editorSaveRequested = Notification.Name("editorSaveRequested")
}
