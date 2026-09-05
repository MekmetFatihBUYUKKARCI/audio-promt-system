import Carbon
import Foundation

enum HotKeyModifier {
    static let control: UInt32 = UInt32(controlKey)
    static let option: UInt32 = UInt32(optionKey)
}

private func hotKeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event, let userData = userData else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handle(id: hotKeyID.id)
    return noErr
}

final class HotKeyManager {
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandlerRef: EventHandlerRef?
    private var nextID: UInt32 = 1

    private static let signature: OSType = {
        var sig: OSType = 0
        for scalar in "AUPR".unicodeScalars { sig = (sig << 8) + OSType(scalar.value) }
        return sig
    }()

    init() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    /// Başarılıysa daha sonra `unregister(id:)` ile kaldırmak için bir
    /// kimlik döndürür; başarısızsa nil.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> UInt32? {
        let id = nextID
        nextID += 1

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref = ref else { return nil }
        hotKeyRefs[id] = ref
        handlers[id] = handler
        return id
    }

    /// Tek bir kısayolu kaldırır — Esc gibi sadece geçici olarak kayıtlı
    /// tuşlar için (bkz. PLAN.md bölüm 7: "Esc sadece kayıt sırasında
    /// kaydedilir, kayıt bitince serbest bırakılır").
    func unregister(id: UInt32) {
        if let ref = hotKeyRefs.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
        handlers.removeValue(forKey: id)
    }

    func unregisterAll() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
    }

    fileprivate func handle(id: UInt32) {
        handlers[id]?()
    }

    deinit {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
