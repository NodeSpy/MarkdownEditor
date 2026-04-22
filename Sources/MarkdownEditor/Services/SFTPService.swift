import Foundation

struct SFTPConnection: Codable, Equatable {
    var host: String
    var port: Int
    var username: String
    var keyPath: String
    var remotePath: String

    var displayName: String {
        "\(username)@\(host)"
    }

    var sshTarget: String {
        "\(username)@\(host)"
    }
}

struct RemoteFileNode: Identifiable, Hashable {
    let id: String
    let name: String
    let fullPath: String
    let isDirectory: Bool

    var icon: String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "md", "markdown", "mdown", "mkd": return "doc.text.fill"
        case "txt": return "doc.text"
        default: return "doc"
        }
    }

    var isMarkdown: Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["md", "markdown", "mdown", "mkd", "txt"].contains(ext)
    }
}

final class SFTPService {
    static let shared = SFTPService()

    private let queue = DispatchQueue(label: "com.markdowneditor.sftp", qos: .userInitiated)

    private let sshOptions: [String] = [
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=10",
        "-o", "BatchMode=yes",
        "-o", "LogLevel=ERROR",
        "-o", "ControlMaster=auto",
        "-o", "ControlPath=/tmp/mkeditor-%r@%h:%p",
        "-o", "ControlPersist=300"
    ]

    // MARK: - Test Connection

    func testConnection(_ conn: SFTPConnection, completion: @escaping (Result<Void, SFTPError>) -> Void) {
        queue.async {
            var args = self.sshOptions
            if !conn.keyPath.isEmpty {
                args += ["-i", conn.keyPath]
            }
            args += ["-p", "\(conn.port)", conn.sshTarget, "echo", "ok"]

            let result = self.runProcess("/usr/bin/ssh", arguments: args)
            DispatchQueue.main.async {
                if result.exitCode == 0 && result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "ok" {
                    completion(.success(()))
                } else {
                    let msg = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(.failure(.connectionFailed(msg.isEmpty ? "Connection failed (exit code \(result.exitCode))" : msg)))
                }
            }
        }
    }

    // MARK: - List Directory

    func listDirectory(_ conn: SFTPConnection, path: String, completion: @escaping (Result<[RemoteFileNode], SFTPError>) -> Void) {
        queue.async {
            let remotePath = path.isEmpty ? "~/" : path
            var args = self.sshOptions
            if !conn.keyPath.isEmpty {
                args += ["-i", conn.keyPath]
            }
            args += ["-p", "\(conn.port)", conn.sshTarget,
                     "LC_ALL=C TERM=dumb command ls -1pF \(self.shellEscape(remotePath))"]

            let result = self.runProcess("/usr/bin/ssh", arguments: args)
            DispatchQueue.main.async {
                guard result.exitCode == 0 else {
                    let msg = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(.failure(.commandFailed(msg.isEmpty ? "ls failed" : msg)))
                    return
                }

                let basePath = remotePath.hasSuffix("/") ? remotePath : remotePath + "/"
                var nodes: [RemoteFileNode] = []

                for line in result.stdout.split(separator: "\n") {
                    let entry = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                    if entry.isEmpty || entry == "./" || entry == "../" { continue }

                    let isDir = entry.hasSuffix("/")
                    let name = isDir ? String(entry.dropLast()) : entry
                    // Skip hidden files, symlink indicators, etc.
                    if name.hasPrefix(".") { continue }
                    // Strip type indicators from ls -F (*, @, =, |)
                    let cleanName: String
                    if !isDir && (entry.hasSuffix("*") || entry.hasSuffix("@") || entry.hasSuffix("=") || entry.hasSuffix("|")) {
                        cleanName = String(entry.dropLast())
                    } else {
                        cleanName = name
                    }

                    let fullPath = basePath + cleanName + (isDir ? "/" : "")

                    nodes.append(RemoteFileNode(
                        id: fullPath,
                        name: cleanName,
                        fullPath: fullPath,
                        isDirectory: isDir
                    ))
                }

                // Sort: directories first, then alphabetical
                nodes.sort { a, b in
                    if a.isDirectory != b.isDirectory { return a.isDirectory }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }

                completion(.success(nodes))
            }
        }
    }

    // MARK: - Resolve Home Directory

    func resolveHomePath(_ conn: SFTPConnection, completion: @escaping (String) -> Void) {
        queue.async {
            var args = self.sshOptions
            if !conn.keyPath.isEmpty {
                args += ["-i", conn.keyPath]
            }
            args += ["-p", "\(conn.port)", conn.sshTarget, "echo $HOME"]

            let result = self.runProcess("/usr/bin/ssh", arguments: args)
            let home = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                completion(home.isEmpty ? "/home/\(conn.username)" : home)
            }
        }
    }

    // MARK: - Read Remote File

    func downloadFile(_ conn: SFTPConnection, remotePath: String, completion: @escaping (Result<String, SFTPError>) -> Void) {
        queue.async {
            var args = self.sshOptions
            if !conn.keyPath.isEmpty {
                args += ["-i", conn.keyPath]
            }
            args += ["-p", "\(conn.port)", conn.sshTarget,
                     "cat \(self.shellEscape(remotePath))"]

            let result = self.runProcess("/usr/bin/ssh", arguments: args)

            DispatchQueue.main.async {
                guard result.exitCode == 0 else {
                    let msg = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(.failure(.commandFailed(msg.isEmpty ? "Failed to read remote file" : msg)))
                    return
                }
                completion(.success(result.stdout))
            }
        }
    }

    // MARK: - Write Remote File

    func uploadFile(_ conn: SFTPConnection, content: String, remotePath: String, completion: @escaping (Result<Void, SFTPError>) -> Void) {
        queue.async {
            var args = self.sshOptions
            if !conn.keyPath.isEmpty {
                args += ["-i", conn.keyPath]
            }
            args += ["-p", "\(conn.port)", conn.sshTarget,
                     "cat > \(self.shellEscape(remotePath))"]

            let result = self.runProcessWithInput("/usr/bin/ssh", arguments: args, input: content)

            DispatchQueue.main.async {
                if result.exitCode == 0 {
                    completion(.success(()))
                } else {
                    let msg = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(.failure(.commandFailed(msg.isEmpty ? "Failed to write remote file" : msg)))
                }
            }
        }
    }

    // MARK: - Helpers

    private func shellEscape(_ path: String) -> String {
        if path.hasPrefix("~/") { return path }
        return "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private struct ProcessResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    private func runProcess(_ launchPath: String, arguments: [String]) -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ProcessResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        defer {
            stdoutHandle.closeFile()
            stderrHandle.closeFile()
        }

        let stdoutData = stdoutHandle.readDataToEndOfFile()
        let stderrData = stderrHandle.readDataToEndOfFile()
        process.waitUntilExit()

        return ProcessResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }

    private func runProcessWithInput(_ launchPath: String, arguments: [String], input: String) -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ProcessResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }

        if let data = input.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
        }
        stdinPipe.fileHandleForWriting.closeFile()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        defer {
            stdoutHandle.closeFile()
            stderrHandle.closeFile()
        }

        let stdoutData = stdoutHandle.readDataToEndOfFile()
        let stderrData = stderrHandle.readDataToEndOfFile()
        process.waitUntilExit()

        return ProcessResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }
}

// MARK: - Errors

enum SFTPError: LocalizedError {
    case connectionFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return msg
        case .commandFailed(let msg): return msg
        }
    }
}
