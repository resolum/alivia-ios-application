import SwiftUI

/// Official Alivia person/heart mark next to the wordmark.
struct AliviaLogo: View {
    var markSize: CGFloat = 28
    var textSize: CGFloat = 28

    var body: some View {
        HStack(spacing: markSize / 3) {
            Canvas { context, size in
                let stroke = min(size.width, size.height) * 0.105
                let style = StrokeStyle(lineWidth: stroke, lineCap: .round)
                let radius = min(size.width, size.height) * 0.17
                let head = Path(ellipseIn: CGRect(x: size.width * 0.5 - radius, y: size.height * 0.2 - radius,
                                                  width: radius * 2, height: radius * 2))
                context.stroke(head, with: .color(AliviaColor.logoTeal), style: style)

                var left = Path()
                left.move(to: CGPoint(x: size.width * 0.28, y: size.height * 0.35))
                left.addCurve(to: CGPoint(x: size.width * 0.47, y: size.height * 0.91),
                              control1: CGPoint(x: size.width * 0.02, y: size.height * 0.37),
                              control2: CGPoint(x: size.width * 0.02, y: size.height * 0.64))
                context.stroke(left, with: .color(AliviaColor.logoTeal), style: style)

                var right = Path()
                right.move(to: CGPoint(x: size.width * 0.72, y: size.height * 0.35))
                right.addCurve(to: CGPoint(x: size.width * 0.53, y: size.height * 0.91),
                               control1: CGPoint(x: size.width * 0.98, y: size.height * 0.37),
                               control2: CGPoint(x: size.width * 0.98, y: size.height * 0.64))
                context.stroke(right, with: .color(AliviaColor.navy), style: style)
            }
            .frame(width: markSize, height: markSize)
            .accessibilityHidden(true)
            Text("Alivia").font(.system(size: textSize, weight: .regular)).foregroundStyle(AliviaColor.navy)
        }
        .accessibilityElement(children: .combine)
    }
}
