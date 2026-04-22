import SwiftUI
import WebKit

final class ExportService: NSObject, WKNavigationDelegate {

    private var pdfWebView: WKWebView?
    private var pdfSaveURL: URL?
    private var pdfWindow: NSWindow?
    private var isExporting: Bool = false

    private static let shared = ExportService()

    private static let pageWidth: CGFloat = 612   // US Letter 72 DPI
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 54       // 0.75 in

    // MARK: - HTML Export

    static func exportHTML(from viewModel: EditorViewModel) {
        viewModel.getHTML { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let html):
                    let fullHTML = wrapInHTMLDocument(html)
                    saveFile(content: fullHTML, type: "html", title: "Export as HTML")
                case .failure(let error):
                    showError("Could not retrieve editor content: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - PDF Export (via NSPrintOperation)

    static func exportPDF(from viewModel: EditorViewModel) {
        viewModel.getHTML { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let html):
                    let fullHTML = Self.buildPDFHTML(html)
                    Self.shared.beginPDFExport(html: fullHTML)
                case .failure(let error):
                    showError("Could not retrieve editor content: \(error.localizedDescription)")
                }
            }
        }
    }

    private func beginPDFExport(html: String) {
        guard !isExporting else {
            Self.showError("A PDF export is already in progress. Please wait for it to finish.")
            return
        }
        isExporting = true

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "document.pdf"
        panel.title = "Export as PDF"
        panel.message = "Choose where to save the PDF"

        guard panel.runModal() == .OK, let url = panel.url else {
            isExporting = false
            return
        }
        pdfSaveURL = url

        let contentWidth = Self.pageWidth - Self.margin * 2

        let config = WKWebViewConfiguration()
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: contentWidth, height: Self.pageHeight),
            configuration: config
        )
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        self.pdfWebView = webView

        let window = NSWindow(
            contentRect: CGRect(x: -10000, y: -10000, width: contentWidth, height: Self.pageHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.orderBack(nil)
        self.pdfWindow = window

        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.printToPDF(webView: webView)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Self.showError("Failed to render PDF content: \(error.localizedDescription)")
        cleanup()
    }

    private func printToPDF(webView: WKWebView) {
        guard let url = pdfSaveURL else { cleanup(); return }

        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: Self.pageWidth, height: Self.pageHeight)
        printInfo.topMargin = Self.margin
        printInfo.bottomMargin = Self.margin
        printInfo.leftMargin = Self.margin
        printInfo.rightMargin = Self.margin
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.jobDisposition = .save
        printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url

        let printOp = webView.printOperation(with: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = false

        printOp.runModal(
            for: pdfWindow ?? NSApp.mainWindow ?? NSWindow(),
            delegate: self,
            didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
            contextInfo: nil
        )
    }

    @objc private func printOperationDidRun(
        _ printOperation: NSPrintOperation,
        success: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if success, let url = self.pdfSaveURL {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else if !success {
                Self.showError("PDF export failed. The print operation did not complete.")
            }
            self.cleanup()
        }
    }

    private func cleanup() {
        pdfWebView?.navigationDelegate = nil
        pdfWebView = nil
        pdfSaveURL = nil
        pdfWindow?.orderOut(nil)
        pdfWindow = nil
        isExporting = false
    }

    // MARK: - PDF HTML Template

    private static func buildPDFHTML(_ bodyHTML: String) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <style>
        @media print {
            html, body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
            font-size: 10.5pt;
            line-height: 1.55;
            color: #1e293b;
            background: white;
        }

        /* ── Typography ── */

        h1, h2, h3, h4, h5, h6 {
            font-weight: 700;
            line-height: 1.25;
            color: #0f172a;
            page-break-after: avoid;
            break-after: avoid;
        }
        h1 {
            font-size: 20pt;
            margin: 0 0 4pt 0;
            padding-bottom: 7pt;
            border-bottom: 2pt solid #2563eb;
        }
        h2 {
            font-size: 14.5pt;
            margin: 20pt 0 6pt 0;
            padding-bottom: 4pt;
            border-bottom: 0.75pt solid #cbd5e1;
        }
        h3 {
            font-size: 12pt;
            margin: 16pt 0 4pt 0;
            color: #334155;
        }
        h4 {
            font-size: 10.5pt;
            margin: 12pt 0 4pt 0;
            color: #475569;
        }
        p {
            margin: 0 0 8pt 0;
            orphans: 3;
            widows: 3;
        }
        strong { font-weight: 700; }
        em { font-style: italic; }
        del, s { text-decoration: line-through; color: #94a3b8; }

        /* ── Links ── */

        a { color: #2563eb; text-decoration: none; }

        /* ── Lists ── */

        ul, ol {
            margin: 0 0 8pt 0;
            padding-left: 18pt;
        }
        li { margin-bottom: 2pt; }
        li > ul, li > ol { margin-bottom: 0; margin-top: 2pt; }

        /* ── Tables ── */

        table {
            width: calc(100% - 1pt);
            border-collapse: collapse;
            border: 0.5pt solid #94a3b8;
            margin: 10pt 0;
            font-size: 8.5pt;
            line-height: 1.4;
            table-layout: auto;
            page-break-inside: avoid;
            break-inside: avoid;
        }
        thead {
            display: table-header-group;
        }
        tbody {
            display: table-row-group;
        }
        tr {
            page-break-inside: avoid;
            break-inside: avoid;
        }
        th, td {
            border: 0.5pt solid #94a3b8;
            padding: 4pt 6pt;
            text-align: left;
            vertical-align: top;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        th {
            background: #f1f5f9;
            font-weight: 700;
            font-size: 8pt;
            text-transform: uppercase;
            letter-spacing: 0.3pt;
            color: #334155;
            white-space: nowrap;
        }
        tr:nth-child(even) { background: #f8fafc; }
        td strong { color: #0f172a; }

        /* ── Code ── */

        code {
            background: #f1f5f9;
            font-family: 'SF Mono', Menlo, Consolas, monospace;
            font-size: 8.5pt;
            padding: 0.5pt 3pt;
            border-radius: 2pt;
            color: #be123c;
        }
        pre {
            background: #f8fafc;
            border: 0.5pt solid #e2e8f0;
            border-radius: 4pt;
            padding: 10pt 12pt;
            margin: 8pt 0;
            white-space: pre-wrap;
            word-wrap: break-word;
            page-break-inside: avoid;
            break-inside: avoid;
        }
        pre code {
            background: transparent;
            padding: 0;
            color: #334155;
            font-size: 8pt;
            line-height: 1.5;
        }

        /* ── Blockquotes ── */

        blockquote {
            border-left: 2.5pt solid #3b82f6;
            background: #eff6ff;
            margin: 8pt 0;
            padding: 8pt 12pt;
            border-radius: 0 3pt 3pt 0;
            color: #475569;
            page-break-inside: avoid;
            break-inside: avoid;
        }
        blockquote p:last-child { margin-bottom: 0; }

        /* ── Horizontal Rule ── */

        hr {
            border: none;
            border-top: 1pt solid #cbd5e1;
            margin: 16pt 0;
        }

        /* ── Images ── */

        img {
            max-width: 100%;
            height: auto;
            page-break-inside: avoid;
            break-inside: avoid;
        }

        /* ── Task Lists ── */

        ul.task-list { list-style: none; padding-left: 0; }
        li.task-list-item { display: flex; align-items: flex-start; gap: 4pt; }

        /* ── KaTeX ── */

        .katex-display { margin: 8pt 0; overflow-x: hidden; }

        /* ── Misc ── */

        .lang-label { display: none; }
        </style>
        </head>
        <body>
        \(bodyHTML)
        </body>
        </html>
        """
    }

    // MARK: - HTML Export Template

    private static func wrapInHTMLDocument(_ bodyHTML: String) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Exported Markdown</title>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
            <style>
                body {
                    max-width: 860px;
                    margin: 40px auto;
                    padding: 0 20px;
                    font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
                    font-size: 16px;
                    line-height: 1.75;
                    color: #1a1a2e;
                }
                h1, h2, h3, h4, h5, h6 { font-weight: 700; margin-top: 1.5em; margin-bottom: 0.5em; }
                h1 { font-size: 2em; border-bottom: 2px solid #e5e7eb; padding-bottom: 0.3em; }
                h2 { font-size: 1.6em; border-bottom: 1px solid #e5e7eb; padding-bottom: 0.2em; }
                h3 { font-size: 1.35em; }
                code { background: #f3f4f6; padding: 0.15em 0.4em; border-radius: 4px; font-size: 0.875em; }
                pre { background: #f3f4f6; border-radius: 8px; padding: 1em; overflow-x: auto; border: 1px solid #e5e7eb; }
                pre code { background: transparent; padding: 0; }
                blockquote { border-left: 4px solid #3b82f6; background: #eff6ff; padding: 0.75em 1.25em; margin: 1em 0; border-radius: 0 6px 6px 0; }
                table { width: 100%; border-collapse: collapse; margin: 1em 0; }
                th, td { border: 1px solid #d1d5db; padding: 0.6em 1em; }
                th { background: #f3f4f6; font-weight: 600; }
                img { max-width: 100%; border-radius: 6px; }
                a { color: #2563eb; text-decoration: none; }
                hr { border: none; border-top: 2px solid #d1d5db; margin: 2em 0; }
            </style>
        </head>
        <body>
        \(bodyHTML)
        </body>
        </html>
        """
    }

    // MARK: - Helpers

    private static func saveFile(content: String, type: String, title: String) {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = "document.\(type)"

        if type == "html" {
            panel.allowedContentTypes = [.html]
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            showError("Failed to save file: \(error.localizedDescription)")
        }
    }

    private static func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Export Error"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
