import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var iconController: MenuBarIconController!
    private let appState = AppState()

    private var historyMenu: NSMenu!
    private var llmToggleItem: NSMenuItem!
    private var vadToggleItem: NSMenuItem!

    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var settingsHostingController: NSViewController?
    private var onboardingHostingController: NSViewController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            iconController = MenuBarIconController(button: button)
        }
        statusItem.menu = buildMenu()
        TextDelivery.requestAccessibilityTrustIfNeeded()
        LaunchAtLogin.registerIfNeeded()

        appState.onIconStateChange = { [weak self] state in
            self?.iconController.apply(state)
        }
        appState.start()

        if !Preferences.shared.onboardingCompleted {
            showOnboarding()
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let recordItem = NSMenuItem(title: "Kayıt başlat/durdur", action: #selector(toggleRecording), keyEquivalent: "1")
        recordItem.keyEquivalentModifierMask = [.control, .option]
        recordItem.target = self
        menu.addItem(recordItem)

        let pasteAgainItem = NSMenuItem(title: "Son metni yapıştır", action: #selector(pasteLastAgain), keyEquivalent: "v")
        pasteAgainItem.keyEquivalentModifierMask = [.control, .option]
        pasteAgainItem.target = self
        menu.addItem(pasteAgainItem)

        menu.addItem(.separator())

        let historyItem = NSMenuItem(title: "Geçmiş", action: nil, keyEquivalent: "")
        historyMenu = NSMenu()
        historyMenu.delegate = self
        historyItem.submenu = historyMenu
        menu.addItem(historyItem)

        menu.addItem(.separator())

        llmToggleItem = NSMenuItem(title: "LLM ile temizle", action: #selector(toggleLLMCleaning), keyEquivalent: "")
        llmToggleItem.target = self
        menu.addItem(llmToggleItem)

        vadToggleItem = NSMenuItem(title: "Sessizlikte otomatik dur", action: #selector(toggleVAD), keyEquivalent: "")
        vadToggleItem.target = self
        menu.addItem(vadToggleItem)

        let clearHistoryItem = NSMenuItem(title: "Geçmişi temizle", action: #selector(clearHistory), keyEquivalent: "")
        clearHistoryItem.target = self
        menu.addItem(clearHistoryItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Ayarlar…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "Audio Promt Hakkında", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Çık", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu !== historyMenu else { return }
        llmToggleItem.state = Preferences.shared.ollamaEnabled ? .on : .off
        vadToggleItem.state = Preferences.shared.vadEnabled ? .on : .off
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === historyMenu else { return }
        menu.removeAllItems()

        let recent = appState.historyStore.entries.prefix(10)
        if recent.isEmpty {
            let empty = NSMenuItem(title: "(henüz kayıt yok)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for entry in recent {
            let preview = entry.text.count > 40 ? String(entry.text.prefix(40)) + "…" : entry.text
            let title = entry.wasLLMCleaned ? preview : "⚠ \(preview)"
            let item = NSMenuItem(title: title, action: #selector(historyItemClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = HistoryEntryBox(entry: entry)
            menu.addItem(item)
        }
    }

    @objc private func historyItemClicked(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? HistoryEntryBox else { return }
        appState.pasteHistoryEntry(box.entry)
    }

    @objc private func toggleRecording() {
        // AppState'in kısayol callback'iyle aynı yolu kullanır.
        appState.handleMenuToggleRecording()
    }

    @objc private func pasteLastAgain() {
        appState.handleMenuPasteLastAgain()
    }

    @objc private func toggleLLMCleaning() {
        Preferences.shared.ollamaEnabled.toggle()
        llmToggleItem.state = Preferences.shared.ollamaEnabled ? .on : .off
    }

    @objc private func toggleVAD() {
        Preferences.shared.vadEnabled.toggle()
        vadToggleItem.state = Preferences.shared.vadEnabled ? .on : .off
    }

    @objc private func clearHistory() {
        appState.historyStore.clear()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(historyStore: appState.historyStore))
            settingsHostingController = hosting
            let window = makeGlassWindow(
                size: NSSize(width: 680, height: 640),
                title: "Audio Promt Ayarları",
                hostingController: hosting
            )
            window.minSize = NSSize(width: 560, height: 480)
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func showOnboarding() {
        let hosting = NSHostingController(rootView: OnboardingView(onDismiss: { [weak self] in
            self?.onboardingWindow?.close()
        }))
        onboardingHostingController = hosting
        let window = makeGlassWindow(
            size: NSSize(width: 400, height: 380),
            title: "Audio Promt'a Hoş Geldin",
            hostingController: hosting
        )
        window.center()
        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Liquid Glass görünümü: `.titled` pencere yerine saydam, kenarlıksız
    /// başlık çubuğu + arkada `NSVisualEffectView` (macOS 26'nın sistem
    /// genelindeki cam malzeme render'ını otomatik alır — SwiftUI içeriği
    /// üstte şeffaf arka planla oturuyor.
    private func makeGlassWindow(size: NSSize, title: String, hostingController: NSViewController) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false

        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.autoresizingMask = [.width, .height]

        hostingController.view.frame = effectView.bounds
        hostingController.view.autoresizingMask = [.width, .height]
        effectView.addSubview(hostingController.view)

        window.contentView = effectView
        return window
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private final class HistoryEntryBox: NSObject {
    let entry: HistoryEntry
    init(entry: HistoryEntry) {
        self.entry = entry
    }
}
