import SwiftUI

/// Small rounded label, optionally with a colored dot, used for statuses and service types.
struct Pill: View {
    let text: String
    let container: Color
    let content: Color
    var dot: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
            Text(text).font(AliviaFont.labelMedium).foregroundStyle(content)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(container, in: Capsule())
    }
}

struct Dot: View {
    let color: Color
    var size: CGFloat = 6

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}
