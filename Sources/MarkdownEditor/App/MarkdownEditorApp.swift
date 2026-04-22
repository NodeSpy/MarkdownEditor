import SwiftUI

@main
struct MarkdownEditorApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        DocumentGroup(newDocument: { MarkdownDocument() }) { file in
            ContentView(document: file.document)
                .environmentObject(settings)
                .frame(minWidth: 700, minHeight: 500)
        }
        .commands {
            AppCommands()
        }
        .defaultSize(width: 1100, height: 750)

        Settings {
            PreferencesView()
                .environmentObject(settings)
        }
    }
}
