import SwiftUI
import WebKit

struct EditorWebView: NSViewRepresentable {
    @ObservedObject var viewModel: EditorViewModel
    @EnvironmentObject var settings: AppSettings

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "editorBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true

        context.coordinator.webView = webView
        viewModel.webView = webView

        loadEditor(webView)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard viewModel.isReady else { return }

        let applied = context.coordinator.appliedSettings
        if applied.theme != settings.theme {
            viewModel.setTheme(settings.theme)
            context.coordinator.appliedSettings.theme = settings.theme
        }
        if applied.fontSize != settings.fontSize {
            viewModel.setFontSize(settings.fontSize)
            context.coordinator.appliedSettings.fontSize = settings.fontSize
        }
        if applied.focusMode != settings.focusMode {
            viewModel.setFocusMode(settings.focusMode)
            context.coordinator.appliedSettings.focusMode = settings.focusMode
        }
        if applied.typewriterMode != settings.typewriterMode {
            viewModel.setTypewriterMode(settings.typewriterMode)
            context.coordinator.appliedSettings.typewriterMode = settings.typewriterMode
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "editorBridge")
        coordinator.viewModel.webView = nil
        let viewModel = coordinator.viewModel
        Task { @MainActor in
            viewModel.isReady = false
        }
    }

    private func loadEditor(_ webView: WKWebView) {
        guard let resourceURL = Bundle.module.url(forResource: "editor", withExtension: "html", subdirectory: "Resources") else {
            print("Error: Could not find editor.html in bundle")
            if let fallback = Bundle.module.url(forResource: "editor", withExtension: "html") {
                webView.loadFileURL(fallback, allowingReadAccessTo: fallback.deletingLastPathComponent())
            }
            return
        }
        let resourceDir = resourceURL.deletingLastPathComponent()
        webView.loadFileURL(resourceURL, allowingReadAccessTo: resourceDir)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let viewModel: EditorViewModel
        weak var webView: WKWebView?

        /// Tracks last-applied settings to avoid redundant JS evaluations
        var appliedSettings = AppliedSettings()

        struct AppliedSettings {
            var theme: AppTheme?
            var fontSize: Double?
            var focusMode: Bool?
            var typewriterMode: Bool?
        }

        init(viewModel: EditorViewModel) {
            self.viewModel = viewModel
            super.init()
        }

        // WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "editorBridge",
                  let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }

            viewModel.handleMessage(json)
        }

        // WKNavigationDelegate
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Editor HTML loaded successfully
        }

        func webView(_ webView: WKWebView,
                      decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
