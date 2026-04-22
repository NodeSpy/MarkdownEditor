import SwiftUI

struct RemoteFileTreeView: View {
    @ObservedObject var viewModel: RemoteFileTreeViewModel
    let onFileOpened: (String, String) -> Void  // (content, remotePath)

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isConnected {
                connectedView
            } else {
                disconnectedView
            }
        }
    }

    // MARK: - Disconnected State

    private var disconnectedView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "network.slash")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("Not connected")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Connect to an SFTP server\nto browse remote files")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Connect...") {
                viewModel.showConnectionSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Connected View

    private var connectedView: some View {
        VStack(spacing: 0) {
            connectionHeader
            Divider()
            navigationBar
            Divider()

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Spacer()
            } else {
                fileList
            }

            if let error = viewModel.error {
                errorBar(error)
            }
        }
        .background {
            Group {
                Button("") { viewModel.navigateUp() }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                    .disabled(viewModel.currentPath == "/")

                Button("") { viewModel.navigateBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!viewModel.canGoBack)

                Button("") { viewModel.navigateForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!viewModel.canGoForward)
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }

    // MARK: - Connection Header

    private var connectionHeader: some View {
        HStack {
            Image(systemName: "network")
                .foregroundStyle(.green)
                .font(.system(size: 12))

            Text(viewModel.connection?.displayName ?? "")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Button(action: { viewModel.showConnectionSheet = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Connection settings")

            Button(action: { viewModel.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button(action: { viewModel.disconnect() }) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Disconnect")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.5))
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack(spacing: 2) {
            Button(action: { viewModel.navigateBack() }) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Back (⌘[)")
            .disabled(!viewModel.canGoBack)
            .accessibilityLabel("Go back")

            Button(action: { viewModel.navigateForward() }) {
                Image(systemName: "chevron.forward")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Forward (⌘])")
            .disabled(!viewModel.canGoForward)
            .accessibilityLabel("Go forward")

            Button(action: { viewModel.navigateUp() }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Go to parent (⌘↑)")
            .disabled(viewModel.currentPath == "/")
            .accessibilityLabel("Go to parent directory")

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)

            breadcrumbTrail
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.3))
    }

    // MARK: - Breadcrumb Trail

    /// Splits `currentPath` into clickable path segments
    private var breadcrumbTrail: some View {
        let segments = breadcrumbSegments(from: viewModel.currentPath)

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.quaternary)
                        }

                        let isLast = index == segments.count - 1
                        if isLast {
                            Text(segment.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                                .id("breadcrumb-last")
                        } else {
                            Button {
                                viewModel.navigateTo(segment.path)
                            } label: {
                                Text(segment.label)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Navigate to \(segment.label)")
                        }
                    }
                }
            }
            .onChange(of: viewModel.currentPath) { _, _ in
                withAnimation {
                    proxy.scrollTo("breadcrumb-last", anchor: .trailing)
                }
            }
        }
    }

    /// Parses an absolute path like `/home/user/docs/` into labeled segments with their full paths
    private func breadcrumbSegments(from path: String) -> [(label: String, path: String)] {
        guard !path.isEmpty else { return [] }

        let components = path.split(separator: "/").map(String.init)
        var segments: [(label: String, path: String)] = [("/", "/")]

        for (i, component) in components.enumerated() {
            let fullPath = "/" + components[0...i].joined(separator: "/") + "/"
            segments.append((component, fullPath))
        }

        return segments
    }

    // MARK: - File List

    private var fileList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if viewModel.currentPath != "/" {
                    parentDirectoryRow
                }

                ForEach(viewModel.nodes) { node in
                    RemoteFileNodeRow(node: node) {
                        handleNodeTap(node)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// A clickable ".." row that navigates to the parent directory
    private var parentDirectoryRow: some View {
        Button(action: { viewModel.navigateUp() }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.up.left")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                Text("..")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to parent directory")
    }

    // MARK: - Error Bar

    private func errorBar(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 10))
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button("Dismiss") {
                viewModel.error = nil
            }
            .font(.system(size: 10))
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Actions

    private func handleNodeTap(_ node: RemoteFileNode) {
        if node.isDirectory {
            viewModel.navigateTo(node.fullPath)
        } else if node.isMarkdown {
            viewModel.openFile(node) { content, remotePath in
                onFileOpened(content, remotePath)
            }
        }
    }
}

// MARK: - Remote File Node Row

struct RemoteFileNodeRow: View {
    let node: RemoteFileNode
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: node.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(node.isDirectory ? Color.accentColor : (node.isMarkdown ? .blue : .secondary))
                    .frame(width: 16)

                Text(node.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                if !node.isDirectory && !node.isMarkdown {
                    Text("unsupported")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!node.isDirectory && !node.isMarkdown)
        .opacity(!node.isDirectory && !node.isMarkdown ? 0.5 : 1.0)
    }
}
