import AppKit
import ApplicationServices

/// v1: panoya yazar (izin gerektirmez). v2: Erişilebilirlik izni varsa
/// CGEvent ile otomatik ⌘V basar, sonra eski pano içeriğini geri yükler.
/// İzin yoksa v1'e sessizce düşer — sistem her durumda kullanılabilir kalır.
@MainActor
enum TextDelivery {
    static func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func deliver(_ text: String) {
        guard AXIsProcessTrusted() else {
            copyToPasteboard(text)
            NSLog("⚠️ Erişilebilirlik izni yok — sadece panoya kopyalandı, ⌘V ile yapıştır")
            return
        }

        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)

        copyToPasteboard(text)
        simulateCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pasteboard.clearContents()
            if let previousContent {
                pasteboard.setString(previousContent, forType: .string)
            }
        }
    }

    /// Uygulama açılışında bir kez çağrılır — izin verilmemişse Sistem
    /// Ayarları'nın Erişilebilirlik listesinde uygulamanın görünmesini
    /// tetikler (kendisi izin istemek için diyalog açar).
    static func requestAccessibilityTrustIfNeeded() {
        // kAXTrustedCheckOptionPrompt sembolüne erişim Swift 6'da
        // eşzamanlılık-güvensiz global sayılıyor; sabit string değeri
        // (Apple'ın belgelediği, değişmeyen anahtar) doğrudan kullanılıyor.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private static func simulateCommandV() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let vKeyCode: CGKeyCode = 9 // kVK_ANSI_V
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
