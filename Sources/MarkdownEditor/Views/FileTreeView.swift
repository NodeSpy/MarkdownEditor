import SwiftUI

struct FileTreeView: View {
    @ObservedObject var viewModel: FileTreeViewModel
    let onFileSelected: (URL) -> Void

    @State private var selectedNodeID: String?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.rootURL == nil {
                emptyState
            } else {
                fileTree
            }
        }
        .onAppear {
            viewModel.loadLastDirectory()
        }
        .onChange(of: selectedNodeID) { _, newID in
            guard let newID,
                  let node = findNode(id: newID, in: viewModel.rootNodes),
                  !node.isDirectory else { return }
            onFileSelected(node.url)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("No folder open")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Open a folder to browse\nand edit Markdown files")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Open Folder...") {
                viewModel.selectDirectory()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - File Tree

    private var fileTree: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 12))

                Text(viewModel.rootURL?.lastPathComponent ?? "")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                Button(action: { viewModel.selectDirectory() }) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Change folder")

                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.5))

            Divider()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.rootNodes, children: \.children, selection: $selectedNodeID) { node in
                    Label {
                        Text(node.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } icon: {
                        Image(systemName: node.icon)
                            .foregroundStyle(node.iconColor)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    // MARK: - Node Lookup

    private func findNode(id: String, in nodes: [FileNode]) -> FileNode? {
        for node in nodes {
            if node.id == id { return node }
            if let children = node.children,
               let found = findNode(id: id, in: children) {
                return found
            }
        }
        return nil
    }
}
