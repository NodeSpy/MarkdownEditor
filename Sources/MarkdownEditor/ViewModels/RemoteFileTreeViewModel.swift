import SwiftUI
import Combine

@MainActor
final class RemoteFileTreeViewModel: ObservableObject {
    @Published var connection: SFTPConnection?
    @Published var currentPath: String = ""
    @Published var nodes: [RemoteFileNode] = []
    @Published var isConnected: Bool = false
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var activeRemoteFilePath: String?
    @Published var showConnectionSheet: Bool = false

    private let service = SFTPService.shared
    private let connectionKey = "lastSFTPConnection"

    /// Incremented on each connect/disconnect to invalidate stale callbacks
    private var connectionGeneration: Int = 0

    /// Incremented on each navigation to discard out-of-order directory listings
    private var navigationGeneration: Int = 0

    /// Visited directory paths for back/forward navigation
    private var navigationHistory: [String] = []

    /// Current position within `navigationHistory`; -1 means no history yet
    private var historyIndex: Int = -1

    /// Whether the current `navigateTo` call was triggered by back/forward (skip history push)
    private var isHistoryNavigation: Bool = false

    // MARK: - History State

    /// `true` when there is at least one previous directory to go back to
    var canGoBack: Bool { historyIndex > 0 }

    /// `true` when the user has gone back and there are forward entries
    var canGoForward: Bool { historyIndex < navigationHistory.count - 1 }

    // MARK: - Connect

    func connect(_ conn: SFTPConnection) {
        connectionGeneration += 1
        let gen = connectionGeneration

        isLoading = true
        error = nil
        connection = conn

        service.testConnection(conn) { [weak self] result in
            guard let self = self, self.connectionGeneration == gen else { return }
            switch result {
            case .success:
                self.isConnected = true
                self.saveConnection(conn)
                self.resolveAndNavigate(conn, generation: gen)
            case .failure(let err):
                self.isLoading = false
                self.isConnected = false
                self.error = err.localizedDescription
            }
        }
    }

    private func resolveAndNavigate(_ conn: SFTPConnection, generation gen: Int) {
        let startPath = conn.remotePath
        if startPath == "~/" || startPath.isEmpty {
            service.resolveHomePath(conn) { [weak self] home in
                guard let self = self, self.connectionGeneration == gen else { return }
                self.navigateTo(home + "/")
            }
        } else {
            navigateTo(startPath.hasSuffix("/") ? startPath : startPath + "/")
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        connectionGeneration += 1
        navigationGeneration += 1
        connection = nil
        currentPath = ""
        nodes = []
        isConnected = false
        isLoading = false
        error = nil
        activeRemoteFilePath = nil
        navigationHistory = []
        historyIndex = -1
    }

    // MARK: - Navigate

    func navigateTo(_ path: String) {
        guard let conn = connection else { return }
        let pushHistory = !isHistoryNavigation
        isHistoryNavigation = false

        navigationGeneration += 1
        let gen = navigationGeneration

        isLoading = true
        error = nil

        service.listDirectory(conn, path: path) { [weak self] result in
            guard let self = self, self.navigationGeneration == gen else { return }
            self.isLoading = false
            switch result {
            case .success(let newNodes):
                self.currentPath = path

                if pushHistory {
                    // Trim any forward history beyond the current index, then append
                    if self.historyIndex < self.navigationHistory.count - 1 {
                        self.navigationHistory.removeSubrange((self.historyIndex + 1)...)
                    }
                    self.navigationHistory.append(path)
                    self.historyIndex = self.navigationHistory.count - 1
                }

                self.nodes = newNodes
            case .failure(let err):
                self.error = err.localizedDescription
            }
        }
    }

    /// Navigate to the parent directory
    func navigateUp() {
        guard currentPath != "/" else { return }
        var components = currentPath.split(separator: "/").map(String.init)
        if !components.isEmpty {
            components.removeLast()
        }
        let parentPath = components.isEmpty ? "/" : "/" + components.joined(separator: "/") + "/"
        navigateTo(parentPath)
    }

    /// Go back to the previously visited directory
    func navigateBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        isHistoryNavigation = true
        navigateTo(navigationHistory[historyIndex])
    }

    /// Go forward to the next directory in history
    func navigateForward() {
        guard canGoForward else { return }
        historyIndex += 1
        isHistoryNavigation = true
        navigateTo(navigationHistory[historyIndex])
    }

    func refresh() {
        if !currentPath.isEmpty {
            isHistoryNavigation = true
            navigateTo(currentPath)
        }
    }

    // MARK: - Open Remote File

    func openFile(_ node: RemoteFileNode, completion: @escaping (String, String) -> Void) {
        guard let conn = connection, !node.isDirectory else { return }
        let gen = connectionGeneration
        isLoading = true
        error = nil

        service.downloadFile(conn, remotePath: node.fullPath) { [weak self] result in
            guard let self = self, self.connectionGeneration == gen else { return }
            self.isLoading = false
            switch result {
            case .success(let content):
                self.activeRemoteFilePath = node.fullPath
                completion(content, node.fullPath)
            case .failure(let err):
                self.error = err.localizedDescription
            }
        }
    }

    // MARK: - Save Remote File

    func saveCurrentFile(content: String) {
        guard let conn = connection, let remotePath = activeRemoteFilePath else { return }
        guard !content.isEmpty else {
            error = "Refusing to save empty content — this would overwrite the remote file"
            return
        }
        isLoading = true
        error = nil

        service.uploadFile(conn, content: content, remotePath: remotePath) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            switch result {
            case .success:
                break
            case .failure(let err):
                self.error = err.localizedDescription
            }
        }
    }

    // MARK: - Persistence

    private func saveConnection(_ conn: SFTPConnection) {
        if let data = try? JSONEncoder().encode(conn) {
            UserDefaults.standard.set(data, forKey: connectionKey)
        }
    }

    func loadLastConnection() -> SFTPConnection? {
        guard let data = UserDefaults.standard.data(forKey: connectionKey),
              let conn = try? JSONDecoder().decode(SFTPConnection.self, from: data)
        else { return nil }
        return conn
    }
}
