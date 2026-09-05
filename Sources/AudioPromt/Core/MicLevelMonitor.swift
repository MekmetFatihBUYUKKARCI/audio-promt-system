import AVFoundation

/// Ayarlar penceresindeki "Sessizlik eşiği" sliderının yanında canlı
/// seviye göstermek için — gerçek kayıttan bağımsız, ayrı ve hafif bir
/// dinleyici. Sadece Ayarlar açıkken çalışır.
final class MicLevelMonitor: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var isRunning = false

    var onLevelUpdate: (@Sendable (Float) -> Void)?

    func start() {
        guard !isRunning else { return }
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self, let channelData = buffer.floatChannelData?[0] else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }
            var sumSquares: Float = 0
            for i in 0..<frameCount {
                sumSquares += channelData[i] * channelData[i]
            }
            let rms = (sumSquares / Float(frameCount)).squareRoot()
            self.onLevelUpdate?(rms)
        }

        try? engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
}
