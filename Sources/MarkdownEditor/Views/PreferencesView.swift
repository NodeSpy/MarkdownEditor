import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            editorTab
                .tabItem {
                    Label("Editor", systemImage: "pencil")
                }

            themeTab
                .tabItem {
                    Label("Themes", systemImage: "paintpalette")
                }

            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 520, height: 420)
    }

    // MARK: - Editor Tab

    private var editorTab: some View {
        Form {
            Section("Editing") {
                Picker("Default Mode", selection: $settings.editorMode) {
                    ForEach(EditorMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Font Size")
                    Spacer()
                    Slider(value: $settings.fontSize, in: 12...24, step: 1) {
                        Text("Font Size")
                    }
                    .frame(width: 200)
                    Text("\(Int(settings.fontSize))px")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }

            Section("Modes") {
                Toggle("Focus Mode", isOn: $settings.focusMode)
                Text("Dims all paragraphs except the one you're editing")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Typewriter Mode", isOn: $settings.typewriterMode)
                Text("Keeps the active line vertically centered in the editor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sidebar") {
                Toggle("Show Sidebar on Launch", isOn: $settings.showSidebar)
                Toggle("Show Outline Panel", isOn: $settings.showOutline)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Theme Tab

    private var themeTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a Theme")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ThemeManager.shared.themes) { theme in
                    ThemeCard(
                        theme: theme,
                        isSelected: settings.theme == theme.id
                    ) {
                        settings.theme = theme.id
                    }
                }
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("File Browser") {
                HStack {
                    Text("Last Opened Directory")
                    Spacer()
                    Text(settings.lastOpenedDirectory.isEmpty ? "None" :
                            (settings.lastOpenedDirectory as NSString).lastPathComponent)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !settings.lastOpenedDirectory.isEmpty {
                    Button("Clear Last Directory") {
                        settings.lastOpenedDirectory = ""
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Built with")
                    Spacer()
                    Text("SwiftUI + WebKit")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: ThemeManager.ThemeInfo
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Preview block
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.previewBg)
                    .frame(height: 80)
                    .overlay {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Circle().fill(theme.previewAccent).frame(width: 6, height: 6)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.previewFg.opacity(0.8))
                                    .frame(width: 60, height: 8)
                            }
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.previewFg.opacity(0.3))
                                .frame(width: 120, height: 6)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.previewFg.opacity(0.3))
                                .frame(width: 100, height: 6)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.previewFg.opacity(0.2))
                                .frame(width: 80, height: 6)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                // Label
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(theme.label)
                            .font(.system(size: 13, weight: .semibold))

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.system(size: 12))
                        }
                    }

                    Text(theme.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(8)
            .background(isSelected ? Color.accentColor.opacity(0.05) : .clear)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
