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
    private let transcriber = Transcriber()
    private let hudController = HUDController()
    let historyStore = HistoryStore()

    private var recordingURL: URL?
    private var lastTranscript: String?
    private var silenceStart: Date?
    private var maxDurationWorkItem: DispatchWorkItem?
    private var escHotKeyID: UInt32?

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
        if recordRegistered == nil {
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
        if pasteAgainRegistered == nil {
            NSLog("⚠️ ⌃⌥V kaydedilemedi")
        }

        let toggleCleaningRegistered = hotKeyManager.register(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: HotKeyModifier.control | HotKeyModifier.option
        ) { [weak self] in
            Task { @MainActor in
                self?.toggleLLMCleaningFromHotKey()
            }
        }
        if toggleCleaningRegistered == nil {
            NSLog("⚠️ ⌃⌥C kaydedilemedi")
        }

        audioRecorder.onLevelUpdate = { [weak self, weak hudController] rms in
            hudController?.updateLevel(rms)
            Task { @MainActor in
                self?.handleLevelForVAD(rms)
            }
        }

        pushToTalkManager.keyCode = Preferences.shared.pushToTalkKey.keyCode
        pushToTalkManager.onPress = { [weak self] in self?.handlePushToTalkPress() }
        pushToTalkManager.onRelease = { [weak self] in self?.handlePushToTalkRelease() }
        pushToTalkManager.start()

        transcriber.prewarm(modelName: Preferences.shared.whisperModel.rawValue)
    }

    /// Ayarlar penceresinde tuş/mod değiştirildiğinde çağrılır.
    func refreshPushToTalkKey() {
        pushToTalkManager.keyCode = Preferences.shared.pushToTalkKey.keyCode
    }

    /// Menüden çağrılır — kısayolla aynı yolu kullanır.
    func handleMenuToggleRecording() {
        toggleRecording()
    }

    /// Menüden çağrılır — kısayolla aynı yolu kullanır.
    func handleMenuPasteLastAgain() {
        pasteLastTranscriptAgain()
    }

    private func toggleLLMCleaningFromHotKey() {
        Preferences.shared.ollamaEnabled.toggle()
        NSLog("⌃⌥C: LLM ile temizle = \(Preferences.shared.ollamaEnabled)")
    }

    private func toggleRecording() {
        switch status {
        case .idle:
            isPushToTalkHoldSession = false
            Task { await beginRecording() }
        case .recording:
            Task { await endRecordingAndTranscribe() }
        case .starting, .transcribing:
            break // meşgul — kısayol yok sayılır (bkz. PLAN.md bölüm 11)
        }
    }

    /// Hızlı bas-bırak (tipik insan dokunuşu ~100-200ms), `beginRecording()`'in
    /// mikrofonu gerçekten başlatma süresinden (birkaç yüz ms, async) daha
    /// hızlı olabiliyor. O anda bırakma gelirse `status` hâlâ `.starting`
    /// oluyor, `.recording` bekleyen guard bunu sessizce yok sayıyordu —
    /// kayıt takılı kalıyor, ikinci basışın bırakması onu durdurana kadar.
    /// Çözüm: bırakma `.starting` sırasında gelirse bayrakla, kayıt fiilen
    /// başlar başlamaz o bayrağa göre hemen durdur.
    private var pendingStopWhileStarting = false

    /// Basılı-tutma sırasında VAD'ı devre dışı bırakmak için — tuş zaten
    /// açık bir durdurma sinyali, cümleler arası doğal sessizlik VAD
    /// tarafından "bitti" sanılıp tuş hâlâ basılıyken kaydı kesiyordu.
    private var isPushToTalkHoldSession = false

    private func handlePushToTalkPress() {
        if Preferences.shared.pushToTalkMode == .toggle {
            toggleRecording()
        } else {
            guard status == .idle else { return }
            pendingStopWhileStarting = false
            isPushToTalkHoldSession = true
            Task { await beginRecording() }
        }
    }

    private func handlePushToTalkRelease() {
        guard Preferences.shared.pushToTalkMode == .hold else { return }
        switch status {
        case .recording:
            Task { await endRecordingAndTranscribe() }
        case .starting:
            pendingStopWhileStarting = true
        case .idle, .transcribing:
            break
        }
    }

    private func handleLevelForVAD(_ rms: Float) {
        let prefs = Preferences.shared
        guard prefs.vadEnabled, status == .recording, !isPushToTalkHoldSession else {
            silenceStart = nil
            return
        }
        if rms < Float(prefs.vadThreshold) {
            if let start = silenceStart {
                if Date().timeIntervalSince(start) >= prefs.vadSilenceDuration {
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
        let prefs = Preferences.shared
        audioRecorder.applyPreferredInputDevice(uid: prefs.microphoneDeviceUID)

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
            scheduleMaxDurationCutoff(after: prefs.maxRecordingDuration)
            registerEscToCancel()

            if pendingStopWhileStarting {
                pendingStopWhileStarting = false
                NSLog("↩️ Basılı-tutma, kayıt başlamadan önce zaten bırakılmıştı — hemen durduruluyor")
                Task { await endRecordingAndTranscribe() }
            }
        } catch {
            status = .idle
            showTransientError("Mikrofon başlatılamadı")
            NSLog("⚠️ Kayıt başlatılamadı: \(error)")
        }
    }

    private func scheduleMaxDurationCutoff(after seconds: TimeInterval) {
        maxDurationWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.status == .recording else { return }
            NSLog("⏱️ Maksimum kayıt süresine ulaşıldı, otomatik durduruluyor")
            self.toggleRecording()
        }
        maxDurationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
    }

    /// Esc — PLAN.md bölüm 7: sadece kayıt sırasında kayıtlı, kayıt
    /// bitince (veya iptal edilince) hemen kaldırılıyor. Böylece Esc
    /// tuşu başka hiçbir zaman/uygulamada çalınmıyor.
    private func registerEscToCancel() {
        escHotKeyID = hotKeyManager.register(keyCode: UInt32(kVK_Escape), modifiers: 0) { [weak self] in
            Task { @MainActor in
                self?.cancelRecording()
            }
        }
    }

    private func unregisterEsc() {
        if let id = escHotKeyID {
            hotKeyManager.unregister(id: id)
            escHotKeyID = nil
        }
    }

    private func cancelRecording() {
        guard status == .recording else { return }
        isPushToTalkHoldSession = false
        unregisterEsc()
        maxDurationWorkItem?.cancel()
        audioRecorder.stop()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil
        status = .idle
        SoundFeedback.recordingStopped()
        hudController.hide()
        onIconStateChange?(.idle)
        NSLog("⎋ Kayıt iptal edildi (Esc)")
    }

    private func endRecordingAndTranscribe() async {
        isPushToTalkHoldSession = false
        unregisterEsc()
        maxDurationWorkItem?.cancel()
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

        let prefs = Preferences.shared
        let vocabulary = Vocabulary.loadFromBundle()

        do {
            let rawText = try await transcriber.transcribe(
                audioPath: url.path,
                modelName: prefs.whisperModel.rawValue,
                languageCode: prefs.languageMode.whisperLanguageCode,
                promptHints: vocabulary.hints
            )
            NSLog("📝 Ham transkript: \(rawText)")

            if !rawText.isEmpty {
                let cleaner = TextCleaner(
                    vocabulary: Vocabulary(hints: vocabulary.hints, corrections: prefs.vocabularyCorrections),
                    thresholds: TextCleaner.Thresholds(
                        maxWordLossFraction: prefs.maxWordLossPercent / 100,
                        minSimilarity: prefs.minSimilarityPercent / 100,
                        timeout: prefs.ollamaTimeout
                    ),
                    ollamaBaseURL: URL(string: prefs.ollamaAddress) ?? URL(string: "http://localhost:11434")!,
                    ollamaModel: prefs.ollamaModel,
                    enabled: prefs.ollamaEnabled
                )
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
