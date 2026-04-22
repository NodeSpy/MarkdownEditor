import SwiftUI
import os

private let logger = Logger(subsystem: "com.markdowneditor.app", category: "ContentView")

struct ContentView: View {
    @ObservedObject var document: MarkdownDocument
    @EnvironmentObject var settings: AppSettings
    @StateObject private var editorVM = EditorViewModel()
    @StateObject private var fileTreeVM = FileTreeViewModel()
    @StateObject private var remoteVM = RemoteFileTreeViewModel()
    @State private var selectedSidebarTab: SidebarTab = .outline
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    enum SidebarTab: String, CaseIterable {
        case files = "Files"
        case remote = "Remote"
        case outline = "Outline"

        var icon: String {
            switch self {
            case .files: return "folder"
            case .remote: return "network"
            case .outline: return "list.bullet.indent"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 360)
        } detail: {
            VStack(spacing: 0) {
                editorToolbar

                EditorWebView(viewModel: editorVM)
                    .environmentObject(settings)

                StatusBarView(viewModel: editorVM)
                    .environmentObject(settings)
            }
        }
        .onAppear {
            logger.info("ContentView appeared — document window is active")
            editorVM.setDocument(document)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    logger.info("Toolbar remote button tapped")
                    remoteVM.showConnectionSheet = true
                } label: {
                    if remoteVM.isConnected {
                        Label(remoteVM.connection?.host ?? "Remote", systemImage: "network")
                            .foregroundStyle(.green)
                    } else {
                        Label("Connect to Remote Server", systemImage: "network")
                    }
                }
                .help("Connect to Remote Server (⇧⌘O)")
            }
        }
        .sheet(isPresented: $remoteVM.showConnectionSheet) {
            RemoteConnectionView(viewModel: remoteVM)
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuConnectRemote)) { _ in
            logger.info("Received .menuConnectRemote notification — presenting sheet")
            remoteVM.showConnectionSheet = true
        }
        .onChange(of: remoteVM.isConnected) { _, connected in
            if connected {
                selectedSidebarTab = .remote
                columnVisibility = .all
            }
        }
        .background(WindowTitleWriter(
            title: remoteVM.activeRemoteFilePath.map { ($0 as NSString).lastPathComponent },
            subtitle: remoteVM.isConnected && remoteVM.activeRemoteFilePath != nil
                ? "\(remoteVM.connection?.displayName ?? "") : \(remoteVM.activeRemoteFilePath ?? "")"
                : nil
        ))
        .onReceive(NotificationCenter.default.publisher(for: .editorSaveRequested)) { _ in
            guard remoteVM.isConnected, remoteVM.activeRemoteFilePath != nil else { return }
            editorVM.getContent { result in
                if case .success(let markdown) = result {
                    remoteVM.saveCurrentFile(content: markdown)
                }
            }
        }
        .focusedObject(editorVM)
        .focusedObject(remoteVM)
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            Picker("Sidebar", selection: $selectedSidebarTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            Divider()

            switch selectedSidebarTab {
            case .files:
                FileTreeView(viewModel: fileTreeVM) { fileURL in
                    openFile(fileURL)
                }
            case .remote:
                RemoteFileTreeView(viewModel: remoteVM) { content, remotePath in
                    openRemoteFile(content: content, remotePath: remotePath)
                }
            case .outline:
                OutlineView(headings: editorVM.headings) { headingId in
                    editorVM.scrollToHeading(headingId)
                }
            }
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Editor Toolbar

    private var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                FormatButton(icon: "bold", tooltip: "Bold (⌘B)") {
                    editorVM.applyFormatting("bold")
                }
                FormatButton(icon: "italic", tooltip: "Italic (⌘I)") {
                    editorVM.applyFormatting("italic")
                }
                FormatButton(icon: "strikethrough", tooltip: "Strikethrough (⇧⌘X)") {
                    editorVM.applyFormatting("strikethrough")
                }

                Divider().frame(height: 20)

                FormatButton(icon: "number", tooltip: "Heading 1") {
                    editorVM.applyFormatting("h1")
                }
                FormatButton(icon: "textformat.size.smaller", tooltip: "Heading 2") {
                    editorVM.applyFormatting("h2")
                }
                FormatButton(icon: "textformat.size.smaller", tooltip: "Heading 3") {
                    editorVM.applyFormatting("h3")
                }

                Divider().frame(height: 20)

                FormatButton(icon: "list.bullet", tooltip: "Bullet List") {
                    editorVM.applyFormatting("ul")
                }
                FormatButton(icon: "list.number", tooltip: "Numbered List") {
                    editorVM.applyFormatting("ol")
                }
                FormatButton(icon: "checklist", tooltip: "Task List") {
                    editorVM.applyFormatting("task")
                }

                Divider().frame(height: 20)

                FormatButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Code") {
                    editorVM.applyFormatting("code")
                }
                FormatButton(icon: "terminal", tooltip: "Code Block") {
                    editorVM.applyFormatting("codeblock")
                }
                FormatButton(icon: "text.quote", tooltip: "Blockquote") {
                    editorVM.applyFormatting("quote")
                }

                Divider().frame(height: 20)

                FormatButton(icon: "link", tooltip: "Link (⌘K)") {
                    editorVM.applyFormatting("link")
                }
                FormatButton(icon: "photo", tooltip: "Image") {
                    editorVM.applyFormatting("image")
                }
                FormatButton(icon: "tablecells", tooltip: "Table") {
                    editorVM.applyFormatting("table")
                }
                FormatButton(icon: "minus", tooltip: "Horizontal Rule") {
                    editorVM.applyFormatting("hr")
                }
                FormatButton(icon: "x.squareroot", tooltip: "Math Block") {
                    editorVM.applyFormatting("math")
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Helpers

    private func openFile(_ url: URL) {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
        else { return }
        remoteVM.activeRemoteFilePath = nil
        document.text = text
        editorVM.sendContentToEditor(text)
    }

    private func openRemoteFile(content: String, remotePath: String) {
        remoteVM.activeRemoteFilePath = remotePath
        document.text = content
        editorVM.sendContentToEditor(content)
    }
}

// MARK: - Format Button

struct FormatButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.clear)
        .cornerRadius(4)
        .help(tooltip)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let menuConnectRemote = Notification.Name("menuConnectRemote")
}

// MARK: - Focused Values (provided via .focusedObject)

// MARK: - Window Title Writer

/// Directly sets `NSWindow.title` and `NSWindow.subtitle`, bypassing `DocumentGroup`'s
/// `NSDocument`-managed title which always shows "Untitled" for unsaved documents.
private struct WindowTitleWriter: NSViewRepresentable {
    var title: String?
    var subtitle: String?

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let currentTitle = title
        let currentSubtitle = subtitle
        Task { @MainActor in
            guard let window = nsView.window else { return }
            if let currentTitle {
                window.title = currentTitle
            }
            window.subtitle = currentSubtitle ?? ""
        }
    }
}
