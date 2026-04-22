import SwiftUI

struct StatusBarView: View {
    @ObservedObject var viewModel: EditorViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 16) {
            // Mode indicator
            Button(action: {
                viewModel.toggleMode()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.currentMode == .preview
                          ? "eye.fill" : "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10))
                    Text(viewModel.currentMode.label)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary)
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("Toggle editor mode")

            Spacer()

            // Stats
            Group {
                Label("\(viewModel.wordCount) words", systemImage: "text.word.spacing")
                Label("\(viewModel.charCount) chars", systemImage: "character.cursor.ibeam")
                Label("\(viewModel.lineCount) lines", systemImage: "list.number")
                Label("\(viewModel.readingTime) min read", systemImage: "clock")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            Spacer()

            // Theme picker
            Picker("", selection: $settings.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.label).tag(theme)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .scaleEffect(0.85)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
