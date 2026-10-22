import SwiftUI

struct EdgeTabView: View {
    let dockSide: DockSide
    let onClick: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onClick) {
            ZStack {
                // Sleek minimalist handle without any icons
                CustomEdgeShape(dockSide: dockSide, radius: 4)
                    .fill(Color(NSColor.labelColor).opacity(isHovered ? 0.45 : 0.22))
                    .overlay(
                        CustomEdgeShape(dockSide: dockSide, radius: 4)
                            .stroke(Color.white.opacity(isHovered ? 0.35 : 0.12), lineWidth: 0.5)
                    )
                    .shadow(
                        color: Color.black.opacity(isHovered ? 0.2 : 0.08),
                        radius: isHovered ? 3 : 1.5,
                        x: dockSide == .right ? -1 : 1,
                        y: 0
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("点击展开 印象笔记 SideNotes")
    }
}

// Shape that rounds only the inner corners (facing the screen interior)
struct CustomEdgeShape: Shape {
    let dockSide: DockSide
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if dockSide == .right {
            // Right edge is flat against screen, top-left and bottom-left are rounded
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                radius: radius,
                startAngle: Angle(degrees: -90),
                endAngle: Angle(degrees: 180),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 90),
                clockwise: true
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        } else {
            // Left edge is flat against screen, top-right and bottom-right are rounded
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                radius: radius,
                startAngle: Angle(degrees: -90),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                radius: radius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }

        return path
    }
}
