import SwiftUI

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    struct ThemeInfo: Identifiable {
        let id: AppTheme
        let label: String
        let description: String
        let previewBg: Color
        let previewFg: Color
        let previewAccent: Color
    }

    let themes: [ThemeInfo] = [
        ThemeInfo(
            id: .light,
            label: "Light",
            description: "Clean and bright, easy on the eyes during the day",
            previewBg: Color.white,
            previewFg: Color(red: 0.1, green: 0.1, blue: 0.18),
            previewAccent: Color(red: 0.23, green: 0.51, blue: 0.96)
        ),
        ThemeInfo(
            id: .dark,
            label: "Dark",
            description: "Tokyo Night inspired dark theme for night owls",
            previewBg: Color(red: 0.1, green: 0.11, blue: 0.15),
            previewFg: Color(red: 0.75, green: 0.79, blue: 0.96),
            previewAccent: Color(red: 0.48, green: 0.64, blue: 0.97)
        ),
        ThemeInfo(
            id: .github,
            label: "GitHub",
            description: "Familiar GitHub-style rendering for README lovers",
            previewBg: Color.white,
            previewFg: Color(red: 0.14, green: 0.16, blue: 0.18),
            previewAccent: Color(red: 0.04, green: 0.41, blue: 0.85)
        ),
        ThemeInfo(
            id: .solarized,
            label: "Solarized",
            description: "Ethan Schoonover's precision color scheme",
            previewBg: Color(red: 0.99, green: 0.96, blue: 0.89),
            previewFg: Color(red: 0.40, green: 0.48, blue: 0.51),
            previewAccent: Color(red: 0.15, green: 0.55, blue: 0.82)
        )
    ]

    private init() {}
}
