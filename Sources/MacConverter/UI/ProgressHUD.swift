import SwiftUI
import AppKit
import Combine

public struct ProgressHUDView: View {
    @ObservedObject var progressManager = ProgressManager.shared
    
    public var body: some View {
        HStack(spacing: 12) {
            // Icon indicator
            ZStack {
                if progressManager.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                } else if progressManager.hasError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    // Mini progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.15), lineWidth: 3)
                        Circle()
                            .trim(from: 0.0, to: CGFloat(progressManager.progress))
                            .stroke(Color.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.2), value: progressManager.progress)
                    }
                    .frame(width: 20, height: 20)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(progressManager.currentTaskName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    if !progressManager.isCompleted && !progressManager.hasError {
                        Text("\(Int(progressManager.progress * 100))%")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else if progressManager.isCompleted {
                        Text("완료")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                if !progressManager.isCompleted && !progressManager.hasError {
                    // Smooth progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.12))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(Color.primary)
                                .frame(width: max(geo.size.width * CGFloat(progressManager.progress), 4), height: 4)
                                .animation(.easeOut(duration: 0.2), value: progressManager.progress)
                        }
                    }
                    .frame(height: 4)
                } else if !progressManager.detailText.isEmpty {
                    Text(progressManager.detailText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 280)
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
    }
}

@MainActor
public final class ProgressHUDController {
    public static let shared = ProgressHUDController()
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?
    
    private init() {
        setupObserver()
    }
    
    private func setupObserver() {
        cancellable = ProgressManager.shared.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRunning in
                if isRunning {
                    self?.show()
                } else {
                    self?.hide()
                }
            }
    }
    
    public func show() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.contentView = NSHostingView(rootView: ProgressHUDView())
            self.panel = panel
        }
        
        // Position at top-right corner of main screen
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 60
        let x = screenRect.maxX - panelWidth - 20
        let y = screenRect.maxY - panelHeight - 16
        
        panel?.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        panel?.orderFront(nil)
    }
    
    public func hide() {
        panel?.orderOut(nil)
    }
}
