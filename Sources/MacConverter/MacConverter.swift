import AppKit

@main
struct MacConverterApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // Menu bar / accessory app without Dock icon
        app.run()
    }
}
