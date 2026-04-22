import SwiftUI
import os
import AppKit

private let logger = Logger(subsystem: "com.markdowneditor.app", category: "AppCommands")

struct AppCommands: Commands {
    @FocusedObject var editorVM: EditorViewModel?
    @FocusedObject var remoteVM: RemoteFileTreeViewModel?

    var body: some Commands {
        // Replace default text editing with our own
        CommandGroup(after: .textEditing) {
            Section {
                Button("Bold") {
                    editorVM?.applyFormatting("bold")
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italic") {
                    editorVM?.applyFormatting("italic")
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Strikethrough") {
                    editorVM?.applyFormatting("strikethrough")
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])

                Button("Inline Code") {
                    editorVM?.applyFormatting("code")
                }
                .keyboardShortcut("`", modifiers: .command)

                Button("Hyperlink") {
                    editorVM?.applyFormatting("link")
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        // Format menu — headings & blocks
        CommandMenu("Format") {
            Section("Headings") {
                Button("Heading 1") {
                    editorVM?.applyFormatting("h1")
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Heading 2") {
                    editorVM?.applyFormatting("h2")
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Heading 3") {
                    editorVM?.applyFormatting("h3")
                }
                .keyboardShortcut("3", modifiers: [.command])

                Button("Heading 4") {
                    editorVM?.applyFormatting("h4")
                }
                .keyboardShortcut("4", modifiers: [.command])
            }

            Divider()

            Section("Blocks") {
                Button("Blockquote") {
                    editorVM?.applyFormatting("quote")
                }
                .keyboardShortcut("'", modifiers: [.command, .shift])

                Button("Code Block") {
                    editorVM?.applyFormatting("codeblock")
                }
                .keyboardShortcut("c", modifiers: [.command, .option])

                Button("Math Block") {
                    editorVM?.applyFormatting("math")
                }
                .keyboardShortcut("m", modifiers: [.command, .option])

                Button("Horizontal Rule") {
                    editorVM?.applyFormatting("hr")
                }
                .keyboardShortcut("-", modifiers: [.command, .shift])
            }

            Divider()

            Section("Lists") {
                Button("Bullet List") {
                    editorVM?.applyFormatting("ul")
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("Numbered List") {
                    editorVM?.applyFormatting("ol")
                }
                .keyboardShortcut("l", modifiers: [.command, .option])

                Button("Task List") {
                    editorVM?.applyFormatting("task")
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }

            Divider()

            Section("Insert") {
                Button("Table") {
                    editorVM?.applyFormatting("table")
                }
                .keyboardShortcut("t", modifiers: [.command, .option])

                Button("Image") {
                    editorVM?.applyFormatting("image")
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
            }
        }

        // View menu additions
        CommandGroup(after: .toolbar) {
            Section {
                Button("Toggle Editor Mode") {
                    editorVM?.toggleMode()
                }
                .keyboardShortcut("/", modifiers: .command)

                Button("Toggle Focus Mode") {
                    editorVM?.toggleFocusMode()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Toggle Typewriter Mode") {
                    editorVM?.toggleTypewriterMode()
                }
                .keyboardShortcut("t", modifiers: [.command, .control])
            }
        }

        // Remote connection + Export commands
        CommandGroup(after: .importExport) {
            Section {
                Button("Connect to Remote Server...") {
                    logger.info("Menu 'Connect to Remote Server' clicked — remoteVM is \(remoteVM == nil ? "nil" : "available")")
                    if let remoteVM = remoteVM {
                        remoteVM.showConnectionSheet = true
                    } else {
                        logger.info("No document open — creating new document first")
                        NSDocumentController.shared.newDocument(nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            logger.info("Posting .menuConnectRemote notification after document creation")
                            NotificationCenter.default.post(name: .menuConnectRemote, object: nil)
                        }
                    }
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Save to Remote Server") {
                    guard let editorVM = editorVM, let remoteVM = remoteVM else { return }
                    guard remoteVM.isConnected, remoteVM.activeRemoteFilePath != nil else { return }
                    editorVM.getContent { result in
                        if case .success(let markdown) = result {
                            remoteVM.saveCurrentFile(content: markdown)
                        }
                    }
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }

            Section {
                Button("Export as HTML...") {
                    guard let editorVM = editorVM else { return }
                    ExportService.exportHTML(from: editorVM)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Export as PDF...") {
                    guard let editorVM = editorVM else { return }
                    ExportService.exportPDF(from: editorVM)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}
