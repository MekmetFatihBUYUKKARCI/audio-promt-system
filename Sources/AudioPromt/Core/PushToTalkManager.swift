import CoreGraphics
import Foundation
import ApplicationServices

/// CGEventTap callback'i C fonksiyon işaretçisi olmalı — HotKeyManager'daki
/// aynı desen (bkz. o dosyadaki not): closure self yakalarsa gerçek zamanlı
/// olay thread'inde çalışırken Swift'in eşzamanlılık kontrolüyle çakışır.
private func pushToTalkTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<PushToTalkManager>.fromOpaque(userInfo).takeUnretainedValue()
    manager.handleTapEvent(type: type, event: event)
    return Unmanaged.passRetained(event)
}

/// Sağ Option (keycode 61) basılı tutma ile kayıt. Erişilebilirlik izni
/// gerektirir — yoksa sessizce devre dışı kalır, ⌃⌥1 aç/kapa yolu her
/// zaman çalışmaya devam eder.
final class PushToTalkManager: @unchecked Sendable {
    private static let rightOptionKeyCode: Int64 = 61

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?
    private var isKeyDown = false

    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    func start() {
        guard AXIsProcessTrusted() else {
            NSLog("⚠️ Basılı-tutma için Erişilebilirlik izni yok, atlanıyor")
            return
        }
        installTap()
    }

    private func installTap() {
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: pushToTalkTapCallback,
            userInfo: selfPointer
        ) else {
            NSLog("⚠️ CGEventTap oluşturulamadı (push-to-talk devre dışı)")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        startHealthCheck()
    }

    fileprivate func handleTapEvent(type: CGEventType, event: CGEvent) {
        guard type == .flagsChanged else { return }
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keycode == Self.rightOptionKeyCode else { return }

        let isPressed = event.flags.contains(.maskAlternate)
        if isPressed, !isKeyDown {
            isKeyDown = true
            let callback = onPress
            DispatchQueue.main.async { callback?() }
        } else if !isPressed, isKeyDown {
            isKeyDown = false
            let callback = onRelease
            DispatchQueue.main.async { callback?() }
        }
    }

    /// PLAN.md Faz 5 madde 3 (topluluk-arastirmasi.md md.4): tap nil
    /// dönmese bile callback hiç tetiklenmeyebilir. 5 saniyede bir
    /// kontrol edip kapalıysa yeniden etkinleştiriyoruz.
    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, let tap = self.eventTap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) {
                NSLog("⚠️ Push-to-talk tap devre dışı kalmış, yeniden kuruluyor")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
    }
}
