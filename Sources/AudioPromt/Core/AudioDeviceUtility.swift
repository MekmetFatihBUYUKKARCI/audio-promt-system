import CoreAudio
import Foundation

struct AudioInputDevice: Identifiable, Hashable {
    let uid: String
    let name: String
    var id: String { uid }
}

enum AudioDeviceUtility {
    static func listInputDevices() -> [AudioInputDevice] {
        listDeviceIDs().compactMap { deviceID in
            guard hasInputStreams(deviceID) else { return nil }
            guard let uid = stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID) else { return nil }
            let name = stringProperty(deviceID, selector: kAudioObjectPropertyName) ?? uid
            return AudioInputDevice(uid: uid, name: name)
        }
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        listDeviceIDs().first { deviceID in
            stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID) == uid
        }
    }

    private static func listDeviceIDs() -> [AudioDeviceID] {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize) == noErr else {
            return []
        }
        let count = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &ids) == noErr else {
            return []
        }
        return ids
    }

    private static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propertySize) == noErr else {
            return false
        }
        return propertySize > 0
    }

    private static func stringProperty(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var propertySize = UInt32(MemoryLayout<CFString?>.size)
        var value: CFString?
        let status = withUnsafeMutablePointer(to: &value) { pointer -> OSStatus in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, pointer)
        }
        guard status == noErr, let value else { return nil }
        return value as String
    }
}
