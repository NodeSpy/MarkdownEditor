import Foundation

struct HeadingItem: Identifiable, Equatable, Hashable {
    let id: String
    let level: Int
    let text: String

    var indentLevel: Int {
        max(0, level - 1)
    }
}
