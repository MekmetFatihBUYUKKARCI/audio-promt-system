import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "mic",
            accessibilityDescription: "Audio Promt"
        )
        statusItem.menu = buildMenu()
        TextDelivery.requestAccessibilityTrustIfNeeded()
        appState.start()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Çık", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
