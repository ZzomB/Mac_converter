import SwiftUI
import AppKit

@MainActor
public final class HUDPanelController: ObservableObject {
    public static let shared = HUDPanelController()
    
    private var panel: NSPanel?
    private var currentActions: [FileAction] = []
    private var currentFiles: [URL] = []
    @Published public var hoveredAction: FileAction? = nil
    
    private var trackingTimer: Timer?
    
    private let totalSize: CGFloat = 280
    private let innerRadius: CGFloat = 44
    private let outerRadius: CGFloat = 126
    
    private init() {}
    
    public var isVisible: Bool {
        return panel?.isVisible ?? false
    }
    
    public func show(actions: [FileAction], files: [URL], at screenLocation: NSPoint) {
        guard !actions.isEmpty else { return }
        
        self.currentActions = actions
        self.currentFiles = files
        self.hoveredAction = nil
        
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: totalSize, height: totalSize),
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .popUpMenu
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            self.panel = panel
        }
        
        let hostingView = NSHostingView(
            rootView: RadialMenuView(
                actions: actions,
                selectedFiles: files,
                onSelect: { [weak self] action in
                    self?.execute(action: action)
                }
            )
        )
        panel?.contentView = hostingView
        
        // Center panel directly on mouse cursor
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(screenLocation, $0.frame, false) }) ?? NSScreen.main else {
            return
        }
        
        let screenRect = screen.visibleFrame
        var originX = screenLocation.x - (totalSize / 2.0)
        var originY = screenLocation.y - (totalSize / 2.0)
        
        // Clamp to screen bounds with safety margin
        originX = max(screenRect.minX + 8, min(originX, screenRect.maxX - totalSize - 8))
        originY = max(screenRect.minY + 8, min(originY, screenRect.maxY - totalSize - 8))
        
        panel?.setFrame(NSRect(x: originX, y: originY, width: totalSize, height: totalSize), display: true)
        panel?.orderFront(nil)
        
        // Start 60 FPS mouse polling timer to ensure instantaneous highlight updates even during system drag
        trackingTimer?.invalidate()
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isVisible else { return }
                self.updateMousePosition(NSEvent.mouseLocation)
            }
        }
    }
    
    // Polar coordinate hit-testing for the radial pie menu
    public func updateMousePosition(_ screenPoint: NSPoint) {
        guard let panel = panel, panel.isVisible, !currentActions.isEmpty else { return }
        
        let panelFrame = panel.frame
        let centerX = panelFrame.midX
        let centerY = panelFrame.midY
        
        let dx = screenPoint.x - centerX
        let dy = screenPoint.y - centerY // In Cocoa, dy is positive UPWARDS
        
        let distance = sqrt(dx * dx + dy * dy)
        
        // Center deadzone or outside radius
        if distance < innerRadius || distance > (outerRadius + 28) {
            if hoveredAction != nil {
                hoveredAction = nil
            }
            return
        }
        
        // In screen coordinates: dx is rightward (+), dy is upward (+)
        // atan2(dx, dy) yields: 0 rad at Top, +pi/2 at Right, +pi at Bottom, -pi/2 at Left
        var angleRad = atan2(dx, dy)
        if angleRad < 0.0 {
            angleRad += 2.0 * .pi
        }
        let angleDeg = angleRad * 180.0 / .pi // 0.0 to 360.0 clockwise starting from Top
        
        let count = currentActions.count
        let stepAngle = 360.0 / Double(count)
        
        let rawIndex = Int(round(angleDeg / stepAngle)) % count
        if rawIndex >= 0 && rawIndex < count {
            let matched = currentActions[rawIndex]
            if hoveredAction != matched {
                hoveredAction = matched
            }
        } else {
            hoveredAction = nil
        }
    }
    
    public func hide() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        
        panel?.orderOut(nil)
        hoveredAction = nil
        currentActions = []
        currentFiles = []
    }
    
    public func releaseAndExecute() {
        guard isVisible else { return }
        if let action = hoveredAction {
            execute(action: action)
        } else {
            hide()
        }
    }
    
    public func execute(action: FileAction) {
        let files = currentFiles
        hide()
        
        guard !files.isEmpty else { return }
        
        Task.detached {
            await ActionDispatcher.dispatch(action: action, files: files)
        }
    }
}
