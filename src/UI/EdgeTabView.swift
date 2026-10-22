import SwiftUI

struct EdgeTabView: View {
    let dockSide: DockSide
    let onClick: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onClick) {
            ZStack {
                // Background shape with rounded corners on inner edge
                CustomEdgeShape(dockSide: dockSide, radius: 10)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 0.95 : 0.82))
                    .overlay(
                        CustomEdgeShape(dockSide: dockSide, radius: 10)
                            .stroke(Color.primary.opacity(isHovered ? 0.25 : 0.12), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(isHovered ? 0.18 : 0.08),
                        radius: isHovered ? 5 : 3,
                        x: dockSide == .right ? -2 : 2,
                        y: 1
                    )

                VStack(spacing: 5) {
                    Image(systemName: dockSide == .right ? "chevron.left" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isHovered ? .blue : .primary.opacity(0.75))

                    Image(systemName: "note.text")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isHovered ? .blue : .secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
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
