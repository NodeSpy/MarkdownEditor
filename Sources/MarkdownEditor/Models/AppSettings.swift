import SwiftUI

enum EditorMode: String, CaseIterable, Identifiable {
    case preview = "preview"
    case source = "source"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .preview: return "Preview"
        case .source: return "Source"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case github = "github"
    case solarized = "solarized"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .github: return "GitHub"
        case .solarized: return "Solarized"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("editorTheme") var theme: AppTheme = .light
    @AppStorage("editorMode") var editorMode: EditorMode = .preview
    @AppStorage("fontSize") var fontSize: Double = 16
    @AppStorage("focusMode") var focusMode: Bool = false
    @AppStorage("typewriterMode") var typewriterMode: Bool = false
    @AppStorage("showSidebar") var showSidebar: Bool = true
    @AppStorage("showOutline") var showOutline: Bool = true
    @AppStorage("sidebarWidth") var sidebarWidth: Double = 240
    @AppStorage("lastOpenedDirectory") var lastOpenedDirectory: String = ""

    private init() {}
}
