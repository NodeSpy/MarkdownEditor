import SwiftUI

struct OutlineView: View {
    let headings: [HeadingItem]
    let onHeadingSelected: (String) -> Void

    var body: some View {
        if headings.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(headings) { heading in
                        OutlineRow(heading: heading, onTap: onHeadingSelected)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "list.bullet.indent")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("No headings")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Add headings to your document\nto see the outline here")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct OutlineRow: View {
    let heading: HeadingItem
    let onTap: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: { onTap(heading.id) }) {
            HStack(spacing: 6) {
                // Level indicator
                RoundedRectangle(cornerRadius: 1)
                    .fill(levelColor)
                    .frame(width: 3, height: levelHeight)

                Text(heading.text)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.leading, CGFloat(heading.indentLevel) * 12 + 8)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(isHovered ? Color.primary.opacity(0.05) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var fontSize: CGFloat {
        switch heading.level {
        case 1: return 13
        case 2: return 12.5
        case 3: return 12
        default: return 11.5
        }
    }

    private var fontWeight: Font.Weight {
        switch heading.level {
        case 1: return .bold
        case 2: return .semibold
        case 3: return .medium
        default: return .regular
        }
    }

    private var levelColor: Color {
        switch heading.level {
        case 1: return .blue
        case 2: return .cyan
        case 3: return .teal
        case 4: return .green
        case 5: return .yellow
        default: return .orange
        }
    }

    private var levelHeight: CGFloat {
        switch heading.level {
        case 1: return 16
        case 2: return 14
        case 3: return 12
        default: return 10
        }
    }
}
