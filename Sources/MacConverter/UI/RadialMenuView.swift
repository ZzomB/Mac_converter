import SwiftUI
import AppKit

// Annular sector shape (Donut wedge)
public struct RadialSectorShape: Shape {
    public var startAngle: Angle
    public var endAngle: Angle
    public var innerRadius: CGFloat
    public var outerRadius: CGFloat
    
    public func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        
        let startRad = CGFloat(startAngle.radians)
        
        let innerStart = CGPoint(
            x: center.x + innerRadius * cos(startRad),
            y: center.y + innerRadius * sin(startRad)
        )
        
        path.move(to: innerStart)
        path.addArc(center: center, radius: innerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: outerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

public struct RadialMenuView: View {
    @ObservedObject var controller = HUDPanelController.shared
    let actions: [FileAction]
    let selectedFiles: [URL]
    let onSelect: (FileAction) -> Void
    
    // Geometry Constants
    private let centerSize: CGFloat = 88
    private let innerRadius: CGFloat = 44
    private let outerRadius: CGFloat = 126
    private let totalSize: CGFloat = 280
    
    public init(
        actions: [FileAction],
        selectedFiles: [URL],
        onSelect: @escaping (FileAction) -> Void
    ) {
        self.actions = actions
        self.selectedFiles = selectedFiles
        self.onSelect = onSelect
    }
    
    public var body: some View {
        ZStack {
            let count = max(actions.count, 1)
            let stepAngle = 360.0 / Double(count)
            let gapDeg: Double = count > 1 ? 2.5 : 0.0
            
            // 1. Outer Slices (Donut Wedges)
            ForEach(0..<count, id: \.self) { index in
                let action = actions[index]
                let isHovered = (controller.hoveredAction == action)
                let midDeg = -90.0 + Double(index) * stepAngle
                let startDeg = midDeg - (stepAngle / 2.0) + (gapDeg / 2.0)
                let endDeg = midDeg + (stepAngle / 2.0) - (gapDeg / 2.0)
                
                let startAngle = Angle(degrees: startDeg)
                let endAngle = Angle(degrees: endDeg)
                
                ZStack {
                    // Wedge background
                    RadialSectorShape(
                        startAngle: startAngle,
                        endAngle: endAngle,
                        innerRadius: innerRadius,
                        outerRadius: outerRadius
                    )
                    .fill(
                        isHovered
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color(red: 0.32, green: 0.74, blue: 0.26), Color(red: 0.25, green: 0.65, blue: 0.20)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        : AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                    )
                    .overlay(
                        RadialSectorShape(
                            startAngle: startAngle,
                            endAngle: endAngle,
                            innerRadius: innerRadius,
                            outerRadius: outerRadius
                        )
                        .stroke(Color.primary.opacity(isHovered ? 0.0 : 0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isHovered ? 0.30 : 0.08), radius: isHovered ? 8 : 3, x: 0, y: 2)
                    
                    // Wedge Text & Icon Label
                    let midRad = (innerRadius + outerRadius) / 2.0
                    let angleRad = midDeg * .pi / 180.0
                    let labelX = (totalSize / 2.0) + midRad * cos(angleRad)
                    let labelY = (totalSize / 2.0) + midRad * sin(angleRad)
                    
                    VStack(spacing: 2) {
                        Image(systemName: action.iconName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isHovered ? .white : .primary)
                        
                        Text(action.displayName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isHovered ? .white : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(width: 58)
                    .position(x: labelX, y: labelY)
                }
                .contentShape(
                    RadialSectorShape(
                        startAngle: startAngle,
                        endAngle: endAngle,
                        innerRadius: innerRadius,
                        outerRadius: outerRadius
                    )
                )
                .onTapGesture {
                    onSelect(action)
                }
            }
            
            // 2. Center Hub (Circle)
            ZStack {
                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.96))
                    .frame(width: centerSize, height: centerSize)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
                
                VStack(spacing: 2) {
                    if let hovered = controller.hoveredAction {
                        Text(hovered.displayName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("놓아서 실행")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "hand.point.up.left.and.text")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("선택")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(width: totalSize, height: totalSize)
    }
}
