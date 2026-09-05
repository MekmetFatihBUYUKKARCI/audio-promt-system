import Foundation
import Carbon

@MainActor
final class AppState {
    enum Status {
        case idle
        case starting
        case recording
        case transcribing
    }

    private(set) var status: Status = .idle

    private let hotKeyManager = HotKeyManager()
    private let audioRecorder = AudioRecorder()
    private let transcriber = Transcriber(modelName: "openai_whisper-large-v3-v20240930_turbo")
    private var recordingURL: URL?
    private var lastTranscript: String?

    func start() {
        let recordRegistered = hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_1),
            modifiers: HotKeyModifier.control | HotKeyModifier.option
        ) { [weak self] in
            Task { @MainActor in
                self?.toggleRecording()
            }
        }
        if !recordRegistered {
            NSLog("⚠️ ⌃⌥1 kaydedilemedi — başka bir uygulama kullanıyor olabilir")
        }

        let pasteAgainRegistered = hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: HotKeyModifier.control | HotKeyModifier.option
        ) { [weak self] in
            Task { @MainActor in
                self?.pasteLastTranscriptAgain()
            }
        }
        if !pasteAgainRegistered {
            NSLog("⚠️ ⌃⌥V kaydedilemedi")
        }
    }

    private func toggleRecording() {
        switch status {
        case .idle:
            Task { await beginRecording() }
        case .recording:
            Task { await endRecordingAndTranscribe() }
        case .starting, .transcribing:
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

    private func endRecordingAndTranscribe() async {
        audioRecorder.stop()
        SoundFeedback.recordingStopped()
        status = .transcribing

        guard let url = recordingURL else {
            status = .idle
            return
        }

        do {
            let text = try await transcriber.transcribe(audioPath: url.path)
            NSLog("📝 Transkript: \(text)")
            if !text.isEmpty {
                TextDelivery.deliver(text)
                lastTranscript = text
            }
        } catch {
            NSLog("⚠️ Transkripsiyon hatası: \(error)")
        }

        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
        status = .idle
    }

    private func pasteLastTranscriptAgain() {
        guard let lastTranscript else { return }
        TextDelivery.deliver(lastTranscript)
        NSLog("↻ Son transkript tekrar teslim edildi")
    }
}
