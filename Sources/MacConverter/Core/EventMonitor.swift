import Foundation
import AppKit
import CoreGraphics

public final class EventMonitor {
    public static let shared = EventMonitor()
    
    private var globalMonitors: [Any] = []
    private var isMouseDown: Bool = false
    private var activeCategory: ActionCategory? = nil
    
    private init() {}
    
    // Checks if the left mouse button is currently held down
    private var isLeftMouseHeld: Bool {
        return isMouseDown || (NSEvent.pressedMouseButtons & 1 != 0)
    }
    
    public func start() {
        stop()
        
        // 1. Monitor Mouse Down
        let downMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.isMouseDown = true
        }
        if let m = downMonitor { globalMonitors.append(m) }
        
        // 2. Monitor Mouse Up (Release to execute or cancel)
        let upMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            guard let self = self else { return }
            self.isMouseDown = false
            self.activeCategory = nil
            
            Task { @MainActor in
                HUDPanelController.shared.releaseAndExecute()
            }
        }
        if let m = upMonitor { globalMonitors.append(m) }
        
        // 3. Monitor Mouse Dragged (Hit testing items)
        let dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { _ in
            let mousePos = NSEvent.mouseLocation
            Task { @MainActor in
                if HUDPanelController.shared.isVisible {
                    HUDPanelController.shared.updateMousePosition(mousePos)
                }
            }
        }
        if let m = dragMonitor { globalMonitors.append(m) }
        
        // 4. Monitor Modifier Keys (Flags Changed: Option -> Conversion, Control -> Processing)
        let flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            guard let self = self else { return }
            
            let isOptionDown = event.modifierFlags.contains(.option)
            let isControlDown = event.modifierFlags.contains(.control)
            
            if self.isLeftMouseHeld {
                if isOptionDown && self.activeCategory == nil {
                    self.activeCategory = .conversion
                    self.triggerHUD(category: .conversion)
                } else if isControlDown && self.activeCategory == nil {
                    self.activeCategory = .processing
                    self.triggerHUD(category: .processing)
                } else if !isOptionDown && !isControlDown && self.activeCategory != nil {
                    // Key Up: cancel if neither modifier is held
                    self.activeCategory = nil
                    Task { @MainActor in
                        HUDPanelController.shared.hide()
                    }
                }
            }
        }
        if let m = flagsMonitor { globalMonitors.append(m) }
        
        // 5. Monitor Key Down / Up ('A' for Conversion, 'B' for Processing, 'ESC' for Cancel)
        let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            
            // Key codes: 0 = 'A', 11 = 'B', 53 = 'ESC'
            if event.keyCode == 53 { // ESC key: emergency cancel
                self.activeCategory = nil
                self.isMouseDown = false
                Task { @MainActor in
                    HUDPanelController.shared.hide()
                }
                return
            }
            
            if self.isLeftMouseHeld {
                if event.keyCode == 0 && self.activeCategory == nil { // 'A'
                    self.activeCategory = .conversion
                    self.triggerHUD(category: .conversion)
                } else if event.keyCode == 11 && self.activeCategory == nil { // 'B'
                    self.activeCategory = .processing
                    self.triggerHUD(category: .processing)
                }
            }
        }
        if let m = keyMonitor { globalMonitors.append(m) }
        
        let keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
            guard let self = self else { return }
            if (event.keyCode == 0 || event.keyCode == 11) && self.activeCategory != nil {
                self.activeCategory = nil
                Task { @MainActor in
                    HUDPanelController.shared.hide()
                }
            }
        }
        if let m = keyUpMonitor { globalMonitors.append(m) }
    }
    
    public func stop() {
        for monitor in globalMonitors {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitors.removeAll()
        isMouseDown = false
        activeCategory = nil
    }
    
    private func triggerHUD(category: ActionCategory) {
        DispatchQueue.global(qos: .userInteractive).async {
            let files = FinderBridge.getSelectedFiles()
            guard !files.isEmpty else { return }
            
            let actions = ContextEngine.determineActions(for: files, category: category)
            guard !actions.isEmpty else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            Task { @MainActor in
                HUDPanelController.shared.show(actions: actions, files: files, at: mouseLocation)
            }
        }
    }
}
