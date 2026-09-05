import Foundation
import Carbon
import ApplicationServices

@MainActor
final class AppState {
    enum Status {
        case idle
        case starting
        case recording
        case transcribing
    }

    enum IconState {
        case idle
        case recording
        case transcribing
        case error
    }

    private(set) var status: Status = .idle

    private let hotKeyManager = HotKeyManager()
    private let pushToTalkManager = PushToTalkManager()
    private let audioRecorder = AudioRecorder()
    private let transcriber = Transcriber(modelName: "openai_whisper-large-v3-v20240930_turbo")
    private let hudController = HUDController()
    let historyStore = HistoryStore()

    private var recordingURL: URL?
    private var lastTranscript: String?

    var ollamaCleaningEnabled = true
    var vadEnabled = true
    private var silenceStart: Date?
    private let silenceThreshold: Float = 0.02
    private let silenceDuration: TimeInterval = 2.0

    /// AppDelegate tarafından menü çubuğu ikonunu güncellemek için atanır.
    var onIconStateChange: ((IconState) -> Void)?

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

        audioRecorder.onLevelUpdate = { [weak self, weak hudController] rms in
            hudController?.updateLevel(rms)
            Task { @MainActor in
                self?.handleLevelForVAD(rms)
            }
        }

        pushToTalkManager.onPress = { [weak self] in self?.startPushToTalk() }
        pushToTalkManager.onRelease = { [weak self] in self?.stopPushToTalk() }
        pushToTalkManager.start()
    }

    /// Menüden çağrılır — kısayolla aynı yolu kullanır.
    func handleMenuToggleRecording() {
        toggleRecording()
    }

    /// Menüden çağrılır — kısayolla aynı yolu kullanır.
    func handleMenuPasteLastAgain() {
        pasteLastTranscriptAgain()
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

    private func startPushToTalk() {
        guard status == .idle else { return }
        Task { await beginRecording() }
    }

    private func stopPushToTalk() {
        guard status == .recording else { return }
        Task { await endRecordingAndTranscribe() }
    }

    private func handleLevelForVAD(_ rms: Float) {
        guard vadEnabled, status == .recording else {
            silenceStart = nil
            return
        }
        if rms < silenceThreshold {
            if let start = silenceStart {
                if Date().timeIntervalSince(start) >= silenceDuration {
                    silenceStart = nil
                    toggleRecording()
                }
            } else {
                silenceStart = Date()
            }
        } else {
            silenceStart = nil
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
            hudController.showRecording()
            onIconStateChange?(.recording)
            NSLog("🎙️ Kayıt başladı: \(url.path)")
        } catch {
            status = .idle
            showTransientError("Mikrofon başlatılamadı")
            NSLog("⚠️ Kayıt başlatılamadı: \(error)")
        }
    }

    private func endRecordingAndTranscribe() async {
        audioRecorder.stop()
        SoundFeedback.recordingStopped()
        status = .transcribing
        hudController.showTranscribing()
        onIconStateChange?(.transcribing)

        guard let url = recordingURL else {
            status = .idle
            onIconStateChange?(.idle)
            hudController.hide()
            return
        }

        do {
            let rawText = try await transcriber.transcribe(audioPath: url.path)
            NSLog("📝 Ham transkript: \(rawText)")

            if !rawText.isEmpty {
                let cleaner = TextCleaner(enabled: ollamaCleaningEnabled)
                let (finalText, wasLLMCleaned) = await cleaner.clean(rawTranscript: rawText)

                let autoPasted = AXIsProcessTrusted()
                TextDelivery.deliver(finalText)
                lastTranscript = finalText
                hudController.showResult(text: finalText, autoPasted: autoPasted)

                historyStore.add(HistoryEntry(
                    id: UUID(),
                    date: Date(),
                    text: finalText,
                    rawText: rawText,
                    wasLLMCleaned: wasLLMCleaned
                ))
            } else {
                hudController.hide()
            }
            onIconStateChange?(.idle)
        } catch {
            NSLog("⚠️ Transkripsiyon hatası: \(error)")
            showTransientError("Transkripsiyon başarısız")
        }

        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
        status = .idle
    }

    private func pasteLastTranscriptAgain() {
        guard let lastTranscript else { return }
        let autoPasted = AXIsProcessTrusted()
        TextDelivery.deliver(lastTranscript)
        hudController.showResult(text: lastTranscript, autoPasted: autoPasted)
        NSLog("↻ Son transkript tekrar teslim edildi")
    }

    func pasteHistoryEntry(_ entry: HistoryEntry) {
        let autoPasted = AXIsProcessTrusted()
        TextDelivery.deliver(entry.text)
        lastTranscript = entry.text
        hudController.showResult(text: entry.text, autoPasted: autoPasted)
    }

    private func showTransientError(_ message: String) {
        hudController.showError(message)
        onIconStateChange?(.error)
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            onIconStateChange?(.idle)
        }
    }
}
