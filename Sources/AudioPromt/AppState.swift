import Foundation
import Carbon

@MainActor
final class AppState {
    enum Status {
        case idle
        case starting
        case recording
    }

    private(set) var status: Status = .idle

    private let hotKeyManager = HotKeyManager()
    private let audioRecorder = AudioRecorder()
    private var recordingURL: URL?

    func start() {
        let registered = hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_1),
            modifiers: HotKeyModifier.control | HotKeyModifier.option
        ) { [weak self] in
            Task { @MainActor in
                self?.toggleRecording()
            }
        }
        if !registered {
            NSLog("⚠️ ⌃⌥1 kaydedilemedi — başka bir uygulama kullanıyor olabilir")
        }
    }

    private func toggleRecording() {
        switch status {
        case .idle:
            Task { await beginRecording() }
        case .recording:
            endRecording()
        case .starting:
            break // meşgul — kısayol yok sayılır (bkz. PLAN.md bölüm 11)
        }
    }

    private func beginRecording() async {
        status = .starting
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("audiopromt-\(UUID().uuidString).wav")
        do {
            try await audioRecorder.start(to: url)
            recordingURL = url
            status = .recording
            SoundFeedback.recordingStarted()
            NSLog("🎙️ Kayıt başladı: \(url.path)")
        } catch {
            status = .idle
            NSLog("⚠️ Kayıt başlatılamadı: \(error)")
        }
    }

    private func endRecording() {
        audioRecorder.stop()
        status = .idle
        SoundFeedback.recordingStopped()
        if let url = recordingURL {
            NSLog("✅ Kayıt tamamlandı: \(url.path)")
        }
    }
}
