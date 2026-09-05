import AVFoundation

/// Kendi durumunu (start/stop) her zaman tek bir çağıran taraftan sırayla
/// yönetir, ama installTap'in callback'i CoreAudio'nun gerçek zamanlı ses
/// thread'inde çalışır — bu yüzden @MainActor DEĞİL: closure'ı MainActor'a
/// bağlamak, ses thread'inde tetiklenince Swift'in eşzamanlılık çalışma
/// zamanının izolasyon ihlali sayıp uygulamayı çökertmesine yol açıyordu.
final class AudioRecorder: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var isRecording = false

    /// Her ham arabellek geldiğinde RMS seviyesi (0...1 civarı) ile
    /// çağrılır — HUD dalga formu (Faz 2) ve VAD sessizlik algılama
    /// (Faz 3) bunu paylaşır. Ses thread'inden çağrılır, @Sendable.
    var onLevelUpdate: (@Sendable (Float) -> Void)?

    static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

    func start(to url: URL) async throws {
        guard !isRecording else { return }

        try await ensureMicrophoneAccess()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let outputFormat = Self.targetFormat

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioRecorderError.converterCreationFailed
        }

        audioFile = try AVAudioFile(forWriting: url, settings: outputFormat.settings)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            if let onLevelUpdate = self.onLevelUpdate, let channelData = buffer.floatChannelData?[0] {
                let frameCount = Int(buffer.frameLength)
                if frameCount > 0 {
                    var sumSquares: Float = 0
                    for i in 0..<frameCount {
                        sumSquares += channelData[i] * channelData[i]
                    }
                    let rms = (sumSquares / Float(frameCount)).squareRoot()
                    onLevelUpdate(rms)
                }
            }

            let ratio = outputFormat.sampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
                return
            }

            var conversionError: NSError?
            let source = SingleShotBufferSource(buffer)
            converter.convert(to: convertedBuffer, error: &conversionError) { _, outStatus in
                if let buffer = source.take() {
                    outStatus.pointee = .haveData
                    return buffer
                }
                outStatus.pointee = .noDataNow
                return nil
            }

            guard conversionError == nil else { return }
            try? self.audioFile?.write(from: convertedBuffer)
        }

        try engine.start()
        isRecording = true
    }

    private func ensureMicrophoneAccess() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else { throw AudioRecorderError.microphoneAccessDenied }
        default:
            throw AudioRecorderError.microphoneAccessDenied
        }
    }

    func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil
        isRecording = false
    }
}

enum AudioRecorderError: Error {
    case converterCreationFailed
    case microphoneAccessDenied
}

/// AVAudioConverter'ın giriş bloğu, "veri bitti" sinyalini almadan tekrar
/// çağırdığında aynı arabelleği ikinci kez döndürmemek için tek seferlik
/// kaynağı burada tutuyoruz. Yalnızca converter.convert çağrısı süresince,
/// tek bir çağıran thread'den kullanılır — @unchecked Sendable bunu ifade eder.
private final class SingleShotBufferSource: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func take() -> AVAudioPCMBuffer? {
        defer { buffer = nil }
        return buffer
    }
}
