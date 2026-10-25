import SwiftUI
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var progressHostingView: NSHostingView<MenuBarView>?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Notification Manager
        _ = NotificationManager.shared
        
        // Initialize Floating Progress HUD
        _ = ProgressHUDController.shared
        
        // Setup Main Edit Menu for Keyboard Shortcuts (Cmd+A, Cmd+C, Cmd+V, etc.)
        setupMainMenu()
        
        // Setup Status Bar Menu
        setupStatusItem()
        
        // Check Accessibility Permissions
        checkPermissions()
        
        // Start Global Event Monitor
        EventMonitor.shared.start()
        
        print("🚀 MacConverter background utility running successfully.")
    }
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit MacConverter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            let hosting = NSHostingView(rootView: MenuBarView())
            hosting.frame = NSRect(x: 0, y: 0, width: 32, height: 22)
            button.addSubview(hosting)
            button.frame = hosting.frame
            self.progressHostingView = hosting
            
            // Build Status Menu
            let menu = NSMenu()
            
            let headerItem = NSMenuItem(title: "Mac Converter (v1.0)", action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            menu.addItem(headerItem)
            
            menu.addItem(NSMenuItem.separator())
            
            let guideHeader = NSMenuItem(title: "단축키 사용 안내:", action: nil, keyEquivalent: "")
            guideHeader.isEnabled = false
            menu.addItem(guideHeader)
            
            let guide1 = NSMenuItem(title: "  • 드래그 + ⌥(Option) 또는 A: 형식 변환", action: nil, keyEquivalent: "")
            guide1.isEnabled = false
            menu.addItem(guide1)
            
            let guide2 = NSMenuItem(title: "  • 드래그 + ⌃(Control) 또는 B: 파일 가공", action: nil, keyEquivalent: "")
            guide2.isEnabled = false
            menu.addItem(guide2)
            
            let guide3 = NSMenuItem(title: "  • 원하는 메뉴 위에서 마우스 릴리즈 ➔ 실행", action: nil, keyEquivalent: "")
            guide3.isEnabled = false
            menu.addItem(guide3)
            
            menu.addItem(NSMenuItem.separator())
            
            let perm1 = NSMenuItem(title: "손쉬운 사용 권한 설정 열기", action: #selector(openAccessibility), keyEquivalent: "")
            perm1.target = self
            menu.addItem(perm1)
            
            let perm2 = NSMenuItem(title: "전체 디스크 접근 권한 설정 열기", action: #selector(openFullDiskAccess), keyEquivalent: "")
            perm2.target = self
            menu.addItem(perm2)
            
            menu.addItem(NSMenuItem.separator())
            
            let quitItem = NSMenuItem(title: "종료 (Quit)", action: #selector(quitApp), keyEquivalent: "q")
            quitItem.target = self
            menu.addItem(quitItem)
            
            statusItem?.menu = menu
        }
    }
    
    private func checkPermissions() {
        if !Permissions.isAccessibilityGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = NSAlert()
                alert.messageText = "손쉬운 사용(Accessibility) 권한 필요"
                alert.informativeText = "Finder 드래그 제스처 및 글로벌 단축키를 감지하려면 손쉬운 사용 권한이 필요합니다. [시스템 설정 열기]를 눌러 MacConverter를 허용해 주세요."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "시스템 설정 열기")
                alert.addButton(withTitle: "나중에")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    Permissions.openAccessibilitySettings()
                }
            }
        }
    }
    
    @objc private func openAccessibility() {
        Permissions.openAccessibilitySettings()
    }
    
    @objc private func openFullDiskAccess() {
        Permissions.openFullDiskAccessSettings()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
