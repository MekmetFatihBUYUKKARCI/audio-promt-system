import AppKit

enum SoundFeedback {
    static func recordingStarted() {
        play("Ping", volume: 0.4)
    }

    static func recordingStopped() {
        play("Pop", volume: 0.4)
    }

    private static func play(_ systemSoundName: String, volume: Float) {
        let sound = NSSound(contentsOfFile: "/System/Library/Sounds/\(systemSoundName).aiff", byReference: true)
        sound?.volume = volume
        sound?.play()
    }
}
