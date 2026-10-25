import SwiftUI
import AppKit

public struct MenuBarView: View {
    @ObservedObject var progressManager = ProgressManager.shared
    
    public var body: some View {
        HStack(spacing: 4) {
            if progressManager.isRunning {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 2)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(progressManager.progress))
                        .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 14, height: 14)
                
                Text("\(Int(progressManager.progress * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            } else {
                Image(systemName: "arrow.triangle.2.circlepath.circle")
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .padding(.horizontal, 4)
    }
}
