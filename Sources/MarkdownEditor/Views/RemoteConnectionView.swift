import SwiftUI
import os

private let logger = Logger(subsystem: "com.markdowneditor.app", category: "RemoteConnectionView")

struct RemoteConnectionView: View {
    @ObservedObject var viewModel: RemoteFileTreeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var host: String = ""
    @State private var port: String = "22"
    @State private var username: String = ""
    @State private var keyPath: String = ""
    @State private var remotePath: String = "~/"
    @State private var isConnecting: Bool = false
    @State private var connectionError: String?
    @State private var timeoutTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            form
            Divider()
            footer
        }
        .frame(width: 420)
        .onAppear {
            logger.info("RemoteConnectionView appeared — SFTP connection sheet is now visible")
            if let last = viewModel.loadLastConnection() {
                host = last.host
                port = "\(last.port)"
                username = last.username
                keyPath = last.keyPath
                remotePath = last.remotePath
            }
            if keyPath.isEmpty {
                let defaultKey = NSHomeDirectory() + "/.ssh/id_rsa"
                if FileManager.default.fileExists(atPath: defaultKey) {
                    keyPath = defaultKey
                } else {
                    let ed25519 = NSHomeDirectory() + "/.ssh/id_ed25519"
                    if FileManager.default.fileExists(atPath: ed25519) {
                        keyPath = ed25519
                    }
                }
            }
        }
        .onDisappear {
            timeoutTask?.cancel()
            timeoutTask = nil
        }
        .onChange(of: viewModel.isConnected) { _, connected in
            guard isConnecting, connected else { return }
            isConnecting = false
            timeoutTask?.cancel()
            timeoutTask = nil
            dismiss()
        }
        .onChange(of: viewModel.error) { _, newError in
            guard isConnecting, let errorMessage = newError else { return }
            isConnecting = false
            timeoutTask?.cancel()
            timeoutTask = nil
            connectionError = errorMessage
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "network")
                .font(.system(size: 18))
                .foregroundStyle(.blue)
            Text("SFTP Connection")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Form

    private var form: some View {
        VStack(spacing: 14) {
            formField(label: "Host", text: $host, placeholder: "example.com")
            formField(label: "Port", text: $port, placeholder: "22")
            formField(label: "Username", text: $username, placeholder: "user")
            keyPathField
            formField(label: "Remote Path", text: $remotePath, placeholder: "~/")

            if let error = connectionError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 11))
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                    Spacer()
                }
            }
        }
        .padding()
    }

    private func formField(label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 90, alignment: .trailing)

            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
        }
    }

    private var keyPathField: some View {
        HStack(alignment: .center) {
            Text("SSH Key")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 90, alignment: .trailing)

            TextField("~/.ssh/id_rsa", text: $keyPath)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            Button("Browse") {
                browseForKey()
            }
            .controlSize(.small)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if isConnecting {
                ProgressView()
                    .scaleEffect(0.6)
                Text("Connecting...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Cancel") {
                isConnecting = false
                timeoutTask?.cancel()
                timeoutTask = nil
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Connect") {
                connectAction()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(host.isEmpty || username.isEmpty || isConnecting)
        }
        .padding()
    }

    // MARK: - Actions

    private func connectAction() {
        isConnecting = true
        connectionError = nil

        let conn = SFTPConnection(
            host: host.trimmingCharacters(in: .whitespaces),
            port: Int(port) ?? 22,
            username: username.trimmingCharacters(in: .whitespaces),
            keyPath: keyPath.trimmingCharacters(in: .whitespaces),
            remotePath: remotePath.trimmingCharacters(in: .whitespaces)
        )

        viewModel.connect(conn)

        timeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, isConnecting else { return }
            isConnecting = false
            connectionError = "Connection timed out. Check host, port, and SSH key settings."
        }
    }

    private func browseForKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/.ssh")
        panel.message = "Select your SSH private key"

        if panel.runModal() == .OK, let url = panel.url {
            keyPath = url.path
        }
    }
}
