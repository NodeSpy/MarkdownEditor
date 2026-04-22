import SwiftUI
import Combine

struct FileNode: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?

    var icon: String {
        if isDirectory { return "folder.fill" }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "markdown", "mdown", "mkd":
            return "doc.text.fill"
        case "txt":
            return "doc.text"
        case "swift":
            return "swift"
        case "json":
            return "curlybraces"
        case "html", "htm":
            return "globe"
        case "css":
            return "paintbrush"
        case "js", "ts":
            return "chevron.left.forwardslash.chevron.right"
        case "png", "jpg", "jpeg", "gif", "svg", "webp":
            return "photo"
        case "pdf":
            return "doc.richtext"
        default:
            return "doc"
        }
    }

    var iconColor: Color {
        if isDirectory { return .accentColor }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "md", "markdown", "mdown", "mkd":
            return .blue
        case "swift":
            return .orange
        case "json":
            return .yellow
        case "html", "htm":
            return .red
        case "css":
            return .purple
        case "js", "ts":
            return .yellow
        default:
            return .secondary
        }
    }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

final class FileTreeViewModel: ObservableObject {
    @Published var rootNodes: [FileNode] = []
    @Published var rootURL: URL?
    @Published var isLoading: Bool = false

    private var directoryMonitor: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    deinit {
        stopMonitoring()
    }

    func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to browse"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            setRootDirectory(url)
        }
    }

    func setRootDirectory(_ url: URL) {
        rootURL = url
        AppSettings.shared.lastOpenedDirectory = url.path
        refresh()
        startMonitoring(url)
    }

    func refresh() {
        guard let rootURL = rootURL else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let nodes = self?.scanDirectory(rootURL) ?? []
            DispatchQueue.main.async {
                self?.rootNodes = nodes
                self?.isLoading = false
            }
        }
    }

    func loadLastDirectory() {
        let path = AppSettings.shared.lastOpenedDirectory
        if !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                setRootDirectory(url)
            }
        }
    }

    // MARK: - Directory Scanning

    private func scanDirectory(_ url: URL, depth: Int = 0) -> [FileNode] {
        guard depth < 8 else { return [] }

        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var nodes: [FileNode] = []

        let sorted = items.sorted { a, b in
            let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if aIsDir != bIsDir { return aIsDir }
            return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
        }

        for item in sorted {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let name = item.lastPathComponent

            // Skip common non-useful directories
            if isDir && ["node_modules", ".git", ".build", "DerivedData", "__pycache__"].contains(name) {
                continue
            }

            let children = isDir ? scanDirectory(item, depth: depth + 1) : nil

            nodes.append(FileNode(
                id: item.path,
                name: name,
                url: item,
                isDirectory: isDir,
                children: children
            ))
        }

        return nodes
    }

    // MARK: - Directory Monitoring

    private func startMonitoring(_ url: URL) {
        stopMonitoring()

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let fd = fileDescriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.refresh()
        }

        source.setCancelHandler { [weak self] in
            if fd >= 0 { close(fd) }
            self?.fileDescriptor = -1
        }

        directoryMonitor = source
        source.resume()
    }

    private func stopMonitoring() {
        directoryMonitor?.cancel()
        directoryMonitor = nil
    }
}
