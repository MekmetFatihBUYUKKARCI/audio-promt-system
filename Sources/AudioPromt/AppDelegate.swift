import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var iconController: MenuBarIconController!
    private let appState = AppState()

    private var historyMenu: NSMenu!
    private var llmToggleItem: NSMenuItem!
    private var vadToggleItem: NSMenuItem!

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
        llmToggleItem.state = .on
        menu.addItem(llmToggleItem)

        vadToggleItem = NSMenuItem(title: "Sessizlikte otomatik dur", action: #selector(toggleVAD), keyEquivalent: "")
        vadToggleItem.target = self
        vadToggleItem.state = .on
        menu.addItem(vadToggleItem)

        let clearHistoryItem = NSMenuItem(title: "Geçmişi temizle", action: #selector(clearHistory), keyEquivalent: "")
        clearHistoryItem.target = self
        menu.addItem(clearHistoryItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Çık", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
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
        appState.ollamaCleaningEnabled.toggle()
        llmToggleItem.state = appState.ollamaCleaningEnabled ? .on : .off
    }

    @objc private func toggleVAD() {
        appState.vadEnabled.toggle()
        vadToggleItem.state = appState.vadEnabled ? .on : .off
    }

    @objc private func clearHistory() {
        appState.historyStore.clear()
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
